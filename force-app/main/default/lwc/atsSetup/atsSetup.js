import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getSetupStatus from '@salesforce/apex/ATSSetupController.getSetupStatus';
import saveApiSettings from '@salesforce/apex/ATSSetupController.saveApiSettings';
import testApiConnection from '@salesforce/apex/ATSSetupController.testApiConnection';
import getAvailableUsers from '@salesforce/apex/ATSSetupController.getAvailableUsers';
import assignPermissionSetToUsers from '@salesforce/apex/ATSSetupController.assignPermissionSetToUsers';
import removePermissionSetFromUser from '@salesforce/apex/ATSSetupController.removePermissionSetFromUser';

export default class AtsSetup extends NavigationMixin(LightningElement) {
    @track status = null;
    isLoading = true;
    error = null;

    // API Settings
    showApiForm = false;
    apiKey = '';
    apiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models';
    apiModel = 'gemini-2.5-flash';
    isSavingApi = false;
    isTesting = false;
    testResult = null;
    testSuccess = false;

    // User Management
    showAddUsers = false;
    @track availableUsers = [];
    @track selectedUserIds = [];
    isLoadingUsers = false;
    isAssigning = false;

    connectedCallback() {
        this._loadStatus();
    }

    async _loadStatus() {
        this.isLoading = true;
        try {
            this.status = await getSetupStatus();
            if (this.status.apiEndpoint) this.apiEndpoint = this.status.apiEndpoint;
            if (this.status.modelName) this.apiModel = this.status.modelName;
        } catch (e) {
            this.error = e.body?.message || e.message || 'Failed to load setup status';
        } finally {
            this.isLoading = false;
        }
    }

    // --- Computed ---

    get hasStatus() { return this.status != null; }

    get apiStatusIcon() { return this.status?.apiKeyConfigured ? 'utility:success' : 'utility:warning'; }
    get apiStatusVariant() { return this.status?.apiKeyConfigured ? 'success' : 'warning'; }
    get apiStatusLabel() { return this.status?.apiKeyConfigured ? 'Configured' : 'Not Configured'; }

    get permStatusIcon() { return this.status?.usersWithPermSet > 0 ? 'utility:success' : 'utility:warning'; }
    get permStatusVariant() { return this.status?.usersWithPermSet > 0 ? 'success' : 'warning'; }
    get permStatusLabel() {
        const count = this.status?.usersWithPermSet || 0;
        return count > 0 ? count + ' user' + (count !== 1 ? 's' : '') + ' assigned' : 'No users assigned';
    }

    get overallReady() { return this.status?.apiKeyConfigured && this.status?.usersWithPermSet > 0; }
    get overallIcon() { return this.overallReady ? 'utility:success' : 'utility:info'; }
    get overallMessage() {
        if (this.overallReady) return 'ATS is ready to use!';
        const missing = [];
        if (!this.status?.apiKeyConfigured) missing.push('Configure the Gemini API key for CV parsing');
        if (!this.status?.usersWithPermSet) missing.push('Assign the ATS permission set to at least one user');
        return 'To complete setup: ' + missing.join(' and ');
    }

    get assignedUsers() { return this.status?.assignedUsers || []; }
    get hasAssignedUsers() { return this.assignedUsers.length > 0; }

    get userOptions() {
        return this.availableUsers.map(u => ({
            label: u.userName + (u.profileName ? ' (' + u.profileName + ')' : ''),
            value: u.userId
        }));
    }

    get modelOptions() {
        return [
            { label: 'Gemini 2.5 Flash', value: 'gemini-2.5-flash' },
            { label: 'Gemini 2.5 Pro', value: 'gemini-2.5-pro' },
            { label: 'Gemini 2.0 Flash', value: 'gemini-2.0-flash' },
            { label: 'Gemini 1.5 Pro', value: 'gemini-1.5-pro' },
            { label: 'Gemini 1.5 Flash', value: 'gemini-1.5-flash' }
        ];
    }

    get testResultClass() {
        return 'test-result ' + (this.testSuccess ? 'test-success' : 'test-error');
    }

    get testResultIcon() { return this.testSuccess ? 'utility:success' : 'utility:error'; }
    get testResultVariant() { return this.testSuccess ? 'success' : 'error'; }

    get step1Icon() { return this.status?.apiKeyConfigured ? 'utility:check' : 'utility:dash'; }
    get step1Variant() { return this.status?.apiKeyConfigured ? 'success' : 'warning'; }
    get step2Icon() { return this.status?.usersWithPermSet > 0 ? 'utility:check' : 'utility:dash'; }
    get step2Variant() { return this.status?.usersWithPermSet > 0 ? 'success' : 'warning'; }

    get hasSelectedUsers() { return this.selectedUserIds.length > 0; }

    // --- API Settings ---

    handleEditApi() {
        this.showApiForm = true;
        this.testResult = null;
    }

    handleCancelApi() {
        this.showApiForm = false;
        this.testResult = null;
    }

    handleApiKeyChange(e) { this.apiKey = e.target.value; }
    handleEndpointChange(e) { this.apiEndpoint = e.target.value; }
    handleModelChange(e) { this.apiModel = e.detail.value; }

    async handleSaveApi() {
        if (!this.apiKey && !this.status?.apiKeyConfigured) {
            this._showToast('Error', 'Please enter an API key', 'error');
            return;
        }

        this.isSavingApi = true;
        try {
            const keyToSave = this.apiKey || null;
            if (keyToSave) {
                await saveApiSettings({
                    apiKey: keyToSave,
                    endpoint: this.apiEndpoint,
                    model: this.apiModel
                });
            } else {
                await saveApiSettings({
                    apiKey: this.status.maskedApiKey === 'Not configured' ? '' : '___KEEP___',
                    endpoint: this.apiEndpoint,
                    model: this.apiModel
                });
            }
            this._showToast('Success', 'API settings saved. Changes may take a moment to take effect.', 'success');
            this.showApiForm = false;
            this.apiKey = '';
            // Reload after short delay for metadata deployment
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this._loadStatus(), 3000);
        } catch (e) {
            this._showToast('Error', e.body?.message || 'Failed to save settings', 'error');
        } finally {
            this.isSavingApi = false;
        }
    }

    async handleTestConnection() {
        this.isTesting = true;
        this.testResult = null;
        try {
            const result = await testApiConnection();
            if (result === 'SUCCESS') {
                this.testResult = 'Connection successful! The Gemini API is reachable.';
                this.testSuccess = true;
            } else {
                this.testResult = result;
                this.testSuccess = false;
            }
        } catch (e) {
            this.testResult = 'ERROR: ' + (e.body?.message || e.message);
            this.testSuccess = false;
        } finally {
            this.isTesting = false;
        }
    }

    // --- Permission Set Management ---

    async handleShowAddUsers() {
        this.showAddUsers = true;
        this.selectedUserIds = [];
        this.isLoadingUsers = true;
        try {
            this.availableUsers = await getAvailableUsers();
        } catch (e) {
            this._showToast('Error', 'Failed to load users', 'error');
        } finally {
            this.isLoadingUsers = false;
        }
    }

    handleCancelAddUsers() {
        this.showAddUsers = false;
        this.selectedUserIds = [];
    }

    handleUserSelection(e) {
        this.selectedUserIds = e.detail.value;
    }

    async handleAssignUsers() {
        if (this.selectedUserIds.length === 0) return;
        this.isAssigning = true;
        try {
            await assignPermissionSetToUsers({ userIds: this.selectedUserIds });
            this._showToast('Success', this.selectedUserIds.length + ' user(s) assigned to ATS', 'success');
            this.showAddUsers = false;
            this.selectedUserIds = [];
            await this._loadStatus();
        } catch (e) {
            this._showToast('Error', e.body?.message || 'Failed to assign permission set', 'error');
        } finally {
            this.isAssigning = false;
        }
    }

    async handleRemoveUser(e) {
        const userId = e.currentTarget.dataset.id;
        const userName = e.currentTarget.dataset.name;
        try {
            await removePermissionSetFromUser({ userId });
            this._showToast('Success', 'Permission removed from ' + userName, 'success');
            await this._loadStatus();
        } catch (err) {
            this._showToast('Error', err.body?.message || 'Failed to remove permission', 'error');
        }
    }

    // --- Navigation ---

    handleOpenHub() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'ATS_Hub'
            }
        });
    }

    // --- Helpers ---

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
