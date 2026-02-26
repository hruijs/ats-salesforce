import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getLatestCvFileId from '@salesforce/apex/CVFileController.getLatestCvFileId';
import getLatestCvFile from '@salesforce/apex/CVFileController.getLatestCvFile';
import parseCvForContact from '@salesforce/apex/CVFileController.parseCvForContact';
import saveParsedDataToContact from '@salesforce/apex/CVFileController.saveParsedDataToContact';

export default class CvPdfViewer extends LightningElement {
    @api recordId;
    @track parsedData = null;

    contentVersionId;
    cvFileName;
    isParsing = false;
    parseSuccess = false;
    parseError = false;
    errorMessage = '';
    isSaving = false;

    wiredFileResult;
    wiredFileInfoResult;

    get pdfUrl() {
        if (this.contentVersionId) {
            return `/sfc/servlet.shepherd/version/download/${this.contentVersionId}`;
        }
        return null;
    }

    get hasData() {
        return this.parsedData !== null;
    }

    get hasSkills() {
        return this.parsedData && this.parsedData.skills && this.parsedData.skills.length > 0;
    }

    get hasLanguages() {
        return this.parsedData && this.parsedData.languages && this.parsedData.languages.length > 0;
    }

    get hasEducation() {
        return this.parsedData && this.parsedData.education && this.parsedData.education.length > 0;
    }

    get hasWorkExperience() {
        return this.parsedData && this.parsedData.workExperience && this.parsedData.workExperience.length > 0;
    }

    get isParseDisabled() {
        return !this.contentVersionId || this.isParsing;
    }

    get isSaveDisabled() {
        return !this.parsedData || this.isSaving;
    }

    @wire(getLatestCvFileId, { recordId: '$recordId' })
    wiredFile(result) {
        this.wiredFileResult = result;
        if (result.data) {
            this.contentVersionId = result.data;
        } else if (result.error) {
            console.error('Error loading CV file:', result.error);
        }
    }

    @wire(getLatestCvFile, { recordId: '$recordId' })
    wiredFileInfo(result) {
        this.wiredFileInfoResult = result;
        if (result.data) {
            this.cvFileName = result.data.Title + '.' + result.data.FileExtension;
        }
    }

    async handleParseCv() {
        this.isParsing = true;
        this.parseSuccess = false;
        this.parseError = false;
        this.errorMessage = '';

        try {
            const result = await parseCvForContact({ contactId: this.recordId });
            this.parsedData = result;
            this.parseSuccess = true;
        } catch (error) {
            this.parseError = true;
            this.errorMessage = error.body ? error.body.message : 'An unexpected error occurred.';
        } finally {
            this.isParsing = false;
        }
    }

    async handleSave() {
        this.isSaving = true;
        try {
            await saveParsedDataToContact({
                contactId: this.recordId,
                parsedDataJson: JSON.stringify(this.parsedData)
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'CV data saved to contact record.',
                    variant: 'success'
                })
            );

            // Refresh the page
            eval("$A.get('e.force:refreshView').fire();");
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body ? error.body.message : 'Failed to save data.',
                    variant: 'error'
                })
            );
        } finally {
            this.isSaving = false;
        }
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;

        // Create a new object to trigger reactivity
        this.parsedData = { ...this.parsedData, [field]: value };
    }
}
