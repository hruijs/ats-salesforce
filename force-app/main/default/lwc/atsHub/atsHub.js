import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';

// Dashboard
import getJobDashboard from '@salesforce/apex/ApplicationController.getJobDashboard';

// New Candidate
import parseCvFromUpload from '@salesforce/apex/ATSHubController.parseCvFromUpload';
import createCandidateWithApplication from '@salesforce/apex/ATSHubController.createCandidateWithApplication';
import getOpenJobs from '@salesforce/apex/ATSHubController.getOpenJobs';

// Job Management
import saveJob from '@salesforce/apex/ATSHubController.saveJob';
import closeJob from '@salesforce/apex/ATSHubController.closeJob';

// Candidates
import getCandidates from '@salesforce/apex/ATSHubController.getCandidates';
import assignCandidateToJob from '@salesforce/apex/ATSHubController.assignCandidateToJob';
import getInterviewsByCandidate from '@salesforce/apex/ATSHubController.getInterviewsByCandidate';

// Pipeline + Interviews
import getApplicationsByJob from '@salesforce/apex/ApplicationController.getApplicationsByJob';
import getPipelineStats from '@salesforce/apex/ApplicationController.getPipelineStats';
import updateApplicationStage from '@salesforce/apex/ApplicationController.updateApplicationStage';
import getApplicationDetail from '@salesforce/apex/ATSHubController.getApplicationDetail';
import saveInterview from '@salesforce/apex/ATSHubController.saveInterview';
import deleteInterview from '@salesforce/apex/ATSHubController.deleteInterview';
import updateApplicationRating from '@salesforce/apex/ATSHubController.updateApplicationRating';

// Dashboard
import getUpcomingInterviews from '@salesforce/apex/ATSHubController.getUpcomingInterviews';

// Users
import getActiveUsers from '@salesforce/apex/ATSHubController.getActiveUsers';

const STAGE_CONFIG = [
    { name: 'New', label: 'New', color: '#0176d3' },
    { name: 'Screening', label: 'Screening', color: '#9050e9' },
    { name: 'Interview', label: 'Interview', color: '#dd7a01' },
    { name: 'Evaluation', label: 'Evaluation', color: '#0d9dda' },
    { name: 'Offer', label: 'Offer', color: '#2e844a' },
    { name: 'Hired', label: 'Hired', color: '#2e844a' }
];

const SOURCE_OPTIONS = [
    { label: 'LinkedIn', value: 'LinkedIn' },
    { label: 'Website', value: 'Website' },
    { label: 'Referral', value: 'Referral' },
    { label: 'Job Board', value: 'Job Board' },
    { label: 'Agency', value: 'Agency' },
    { label: 'Other', value: 'Other' }
];

const JOB_TYPE_OPTIONS = [
    { label: 'Full-time', value: 'Full-time' },
    { label: 'Part-time', value: 'Part-time' },
    { label: 'Contract', value: 'Contract' },
    { label: 'Internship', value: 'Internship' },
    { label: 'Freelance', value: 'Freelance' }
];

const STATUS_OPTIONS = [
    { label: 'Open', value: 'Open' },
    { label: 'On Hold', value: 'On Hold' },
    { label: 'Closed', value: 'Closed' }
];

const INTERVIEW_TYPE_OPTIONS = [
    { label: 'Phone Screen', value: 'Phone Screen' },
    { label: 'Video Call', value: 'Video Call' },
    { label: 'On-site', value: 'On-site' },
    { label: 'Technical', value: 'Technical' },
    { label: 'Panel', value: 'Panel' },
    { label: 'Culture Fit', value: 'Culture Fit' },
    { label: 'Final Round', value: 'Final Round' }
];

const INTERVIEW_STATUS_OPTIONS = [
    { label: 'Scheduled', value: 'Scheduled' },
    { label: 'Completed', value: 'Completed' },
    { label: 'Cancelled', value: 'Cancelled' },
    { label: 'No Show', value: 'No Show' },
    { label: 'Rescheduled', value: 'Rescheduled' }
];

const PRIORITY_OPTIONS = [
    { label: 'Low', value: 'Low' },
    { label: 'Medium', value: 'Medium' },
    { label: 'High', value: 'High' },
    { label: 'Urgent', value: 'Urgent' }
];

export default class AtsHub extends NavigationMixin(LightningElement) {
    // Tab state
    activeTab = 'dashboard';

    // Global loading overlay
    globalLoading = false;
    globalLoadingMessage = '';

    // Dashboard state
    @track dashboardData = [];
    dashboardLoading = false;
    wiredDashboardResult;
    wiredOpenJobsResult;

    // New Candidate state
    @track parsedData = {};
    @track openJobs = [];
    selectedJobId = '';
    selectedSource = 'LinkedIn';
    base64Pdf = null;
    pdfFileName = '';
    pdfFileSizeBytes = 0;
    isParsing = false;
    isCreating = false;
    parseSuccess = false;
    parseError = false;
    errorMessage = '';
    createSuccess = false;
    createdContactId = null;
    showParsedData = false;
    fileReady = false;

    // Candidates state
    @track candidatesList = [];
    candidateSearchTerm = '';
    candidatesLoading = false;
    candidatesLoaded = false;
    showCandidateModal = false;
    @track selectedCandidate = {};
    assignJobId = '';
    assignSource = 'LinkedIn';
    isAssigning = false;
    _candidateSearchTimeout = null;
    _candidateSearchId = 0;

    // Candidate Interviews state
    @track candidateInterviews = [];
    @track candidateApplications = [];
    candidateInterviewsLoading = false;

    // Dashboard upcoming interviews
    @track upcomingInterviews = [];
    wiredUpcomingResult;
    showUpcomingEditModal = false;

    // Users
    @track activeUsers = [];
    wiredUsersResult;

    // Pipeline state
    @track pipelineApplications = [];
    pipelineStats = null;
    selectedPipelineJobId = '';
    @track pipelineJobs = [];
    draggedApplicationId = null;
    pipelineLoading = false;
    pipelineUpdating = false;
    _didDrag = false;

    // Pipeline Detail / Interview state
    showPipelineDetailModal = false;
    pipelineDetailLoading = false;
    @track pipelineDetail = {};
    showInterviewForm = false;
    @track interviewForm = {};
    isSavingInterview = false;
    interviewFormContext = ''; // 'pipeline' or 'candidate'
    editingInterviewJobTitle = '';

    // Job Modal state
    showJobModal = false;
    isSavingJob = false;
    @track jobForm = {};
    get isEditingJob() { return !!this.jobForm.Id; }

    get sourceOptions() { return SOURCE_OPTIONS; }
    get jobTypeOptions() { return JOB_TYPE_OPTIONS; }
    get statusOptions() { return STATUS_OPTIONS; }
    get priorityOptions() { return PRIORITY_OPTIONS; }
    get interviewTypeOptions() { return INTERVIEW_TYPE_OPTIONS; }
    get interviewStatusOptions() { return INTERVIEW_STATUS_OPTIONS; }

    // ─── Tab getters ───
    get dashboardContentClass() {
        return 'tab-content' + (this.activeTab !== 'dashboard' ? ' tab-hidden' : '');
    }
    get newCandidateContentClass() {
        return 'tab-content' + (this.activeTab !== 'newCandidate' ? ' tab-hidden' : '');
    }
    get candidatesContentClass() {
        return 'tab-content' + (this.activeTab !== 'candidates' ? ' tab-hidden' : '');
    }
    get pipelineContentClass() {
        return 'tab-content' + (this.activeTab !== 'pipeline' ? ' tab-hidden' : '');
    }

    get tabDashboardClass() {
        return 'tab-btn' + (this.activeTab === 'dashboard' ? ' active' : '');
    }
    get tabNewCandidateClass() {
        return 'tab-btn' + (this.activeTab === 'newCandidate' ? ' active' : '');
    }
    get tabCandidatesClass() {
        return 'tab-btn' + (this.activeTab === 'candidates' ? ' active' : '');
    }
    get tabPipelineClass() {
        return 'tab-btn' + (this.activeTab === 'pipeline' ? ' active' : '');
    }

    // ─── Dashboard getters ───
    get hasData() {
        return this.dashboardData && this.dashboardData.length > 0;
    }
    get totalOpenJobs() {
        return this.dashboardData.length;
    }
    get totalActiveCandidates() {
        return this.dashboardData.reduce((sum, item) => sum + (item.stats.totalActive || 0), 0);
    }
    get totalInterviewsThisWeek() {
        return this.dashboardData.reduce((sum, item) => sum + (item.interviewsThisWeek || 0), 0);
    }
    get totalHired() {
        return this.dashboardData.reduce((sum, item) => sum + (item.stats.totalHired || 0), 0);
    }

    // ─── New Candidate getters ───
    get hasSkills() { return this.parsedData?.skills?.length > 0; }
    get hasLanguages() { return this.parsedData?.languages?.length > 0; }
    get hasEducation() { return this.parsedData?.education?.length > 0; }
    get hasWorkExperience() { return this.parsedData?.workExperience?.length > 0; }
    get isParseDisabled() { return !this.fileReady || this.isParsing; }
    get isCreateDisabled() { return !this.showParsedData || this.isCreating; }

    get dropZoneClass() {
        return 'flex-fill' + (this.fileReady ? ' section-hidden' : '');
    }
    get pdfViewClass() {
        return 'flex-fill' + (this.fileReady ? '' : ' section-hidden');
    }
    get parsedDataClass() {
        return 'flex-fill' + (this.showParsedData ? '' : ' section-hidden');
    }
    get emptyDataClass() {
        return 'flex-fill' + (this.showParsedData ? ' section-hidden' : '');
    }

    get parseButtonLabel() {
        return this.isParsing ? 'Parsing...' : 'Parse CV';
    }
    get createButtonLabel() {
        return this.isCreating ? 'Creating...' : 'Create Candidate';
    }

    get pdfFileSize() {
        if (this.pdfFileSizeBytes) {
            const kb = this.pdfFileSizeBytes / 1024;
            if (kb > 1024) {
                return (kb / 1024).toFixed(1) + ' MB';
            }
            return Math.round(kb) + ' KB';
        }
        return '';
    }

    get jobOptions() {
        const opts = [{ label: '-- No job (talent pool) --', value: '' }];
        if (this.openJobs) {
            this.openJobs.forEach(j => {
                let label = j.Title__c;
                if (j.Department__c) label += ' — ' + j.Department__c;
                if (j.Location__c) label += ' (' + j.Location__c + ')';
                opts.push({ label, value: j.Id });
            });
        }
        return opts;
    }

    // ─── Candidates getters ───
    get hasCandidates() { return this.candidatesList && this.candidatesList.length > 0; }
    get candidateCountLabel() {
        const count = this.candidatesList ? this.candidatesList.length : 0;
        return count + ' candidate' + (count !== 1 ? 's' : '');
    }
    get candidatesEmptyMessage() {
        return this.candidateSearchTerm
            ? 'No candidates match your search. Try a different term.'
            : 'No candidates have been added yet. Upload a CV to get started.';
    }
    get assignButtonLabel() { return this.isAssigning ? 'Assigning...' : 'Assign'; }
    get isAssignDisabled() { return !this.assignJobId || this.isAssigning; }

    // ─── Candidate Interview getters ───
    get candidateInterviewCount() { return this.candidateInterviews ? this.candidateInterviews.length : 0; }
    get hasCandidateInterviews() { return this.candidateInterviews && this.candidateInterviews.length > 0; }
    get canAddCandidateInterview() { return this.candidateApplications && this.candidateApplications.length > 0; }
    get candidateAppOptions() {
        return (this.candidateApplications || []).map(a => ({
            label: (a.jobTitle || 'Unknown Job') + ' (' + a.stage + ')',
            value: a.applicationId
        }));
    }
    get isInterviewFormCandidateContext() { return this.interviewFormContext === 'candidate'; }
    get isNewInterview() { return !this.interviewForm.Id; }

    // ─── User getters ───
    get userOptions() {
        const opts = [{ label: '-- No interviewer --', value: '' }];
        (this.activeUsers || []).forEach(u => {
            opts.push({ label: u.userName, value: u.userId });
        });
        return opts;
    }

    // ─── Dashboard upcoming getters ───
    get hasUpcomingInterviews() { return this.upcomingInterviews && this.upcomingInterviews.length > 0; }

    // ─── Pipeline getters ───
    get pipelineJobOptions() {
        const opts = [{ label: '-- Select a job --', value: '' }];
        if (this.pipelineJobs) {
            this.pipelineJobs.forEach(j => {
                let label = j.Title__c;
                if (j.Department__c) label += ' — ' + j.Department__c;
                opts.push({ label, value: j.Id });
            });
        }
        return opts;
    }

    get hasPipelineJob() { return !!this.selectedPipelineJobId; }

    get stages() {
        return STAGE_CONFIG.map(stageConfig => {
            const apps = this.pipelineApplications
                .filter(app => app.stage === stageConfig.name)
                .map(app => ({
                    ...app,
                    initials: this._getInitials(app.candidateName),
                    stars: this._getStars(app.overallRating),
                    daysInStage: Math.round(app.daysInStage || 0)
                }));

            return {
                ...stageConfig,
                count: apps.length,
                applications: apps,
                hasApplications: apps.length > 0,
                columnClass: 'kanban-column',
                dotClass: `column-dot dot-${stageConfig.name.toLowerCase()}`
            };
        });
    }

    // ─── Pipeline Detail getters ───
    get pipelineDetailStars() {
        return this._getStars(this.pipelineDetail.overallRating);
    }
    get saveInterviewButtonLabel() {
        return this.isSavingInterview ? 'Saving...' : 'Save Interview';
    }
    get isSaveInterviewDisabled() {
        return this.isSavingInterview ||
            !this.interviewForm.Interview_Type__c ||
            !this.interviewForm.Scheduled_Date__c ||
            !this.interviewForm.Round__c;
    }

    // ─── Job Modal getters ───
    get jobModalTitle() {
        return this.isEditingJob ? 'Edit Job' : 'New Job';
    }
    get saveJobButtonLabel() {
        if (this.isSavingJob) return 'Saving...';
        return this.isEditingJob ? 'Update Job' : 'Create Job';
    }
    get isSaveJobDisabled() {
        return this.isSavingJob || !this.jobForm.Title__c;
    }

    // ─── Wire methods ───
    @wire(getJobDashboard)
    wiredDashboard(result) {
        this.wiredDashboardResult = result;
        if (result.data) {
            this.dashboardData = result.data.map(item => {
                const maxCount = Math.max(
                    item.stats.totalNew || 0,
                    item.stats.totalScreening || 0,
                    item.stats.totalInterview || 0,
                    item.stats.totalEvaluation || 0,
                    item.stats.totalOffer || 0,
                    item.stats.totalHired || 0,
                    1
                );
                return {
                    ...item,
                    priorityClass: 'priority-badge priority-' + (item.job.Priority__c || 'Medium').toLowerCase(),
                    newBarStyle: `height: ${Math.max((item.stats.totalNew / maxCount) * 100, 4)}%`,
                    screeningBarStyle: `height: ${Math.max((item.stats.totalScreening / maxCount) * 100, 4)}%`,
                    interviewBarStyle: `height: ${Math.max((item.stats.totalInterview / maxCount) * 100, 4)}%`,
                    evalBarStyle: `height: ${Math.max((item.stats.totalEvaluation / maxCount) * 100, 4)}%`,
                    offerBarStyle: `height: ${Math.max((item.stats.totalOffer / maxCount) * 100, 4)}%`,
                    hiredBarStyle: `height: ${Math.max((item.stats.totalHired / maxCount) * 100, 4)}%`
                };
            });
        }
    }

    @wire(getOpenJobs)
    wiredOpenJobs(result) {
        this.wiredOpenJobsResult = result;
        if (result.data) {
            this.openJobs = result.data;
            this.pipelineJobs = result.data;
        }
    }

    @wire(getActiveUsers)
    wiredUsers(result) {
        this.wiredUsersResult = result;
        if (result.data) {
            this.activeUsers = result.data;
        }
    }

    @wire(getUpcomingInterviews)
    wiredUpcoming(result) {
        this.wiredUpcomingResult = result;
        if (result.data) {
            this.upcomingInterviews = (result.data || []).map(ui => {
                const d = ui.scheduledDate ? new Date(ui.scheduledDate) : null;
                const names = [ui.interviewerName, ui.interviewer2Name].filter(Boolean);
                return {
                    ...ui,
                    formattedDay: d ? d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' }) : '',
                    formattedTime: d ? d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }) : '',
                    statusBadgeClass: 'upcoming-status status-' + (ui.status || 'scheduled').toLowerCase().replace(/\s+/g, '-'),
                    interviewersDisplay: names.length > 0 ? names.join(', ') : '',
                    hasInterviewers: names.length > 0
                };
            });
        }
    }

    // ─── Tab handlers ───
    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
        if (this.activeTab === 'candidates' && !this.candidatesLoaded) {
            this._loadCandidates();
        }
    }

    // ─── Dashboard handlers ───
    async handleRefresh() {
        this.dashboardLoading = true;
        try {
            const promises = [
                refreshApex(this.wiredDashboardResult),
                refreshApex(this.wiredOpenJobsResult),
                refreshApex(this.wiredUpcomingResult)
            ];
            if (this.candidatesLoaded) {
                promises.push(this._loadCandidates());
            }
            await Promise.all(promises);
        } finally {
            this.dashboardLoading = false;
        }
    }

    handleUpcomingCardClick(event) {
        const ivId = event.currentTarget.dataset.id;
        const ui = this.upcomingInterviews.find(u => u.id === ivId);
        if (!ui) return;

        let dateVal = '';
        if (ui.scheduledDate) {
            const d = new Date(ui.scheduledDate);
            dateVal = d.toISOString().slice(0, 16);
        }

        this.interviewFormContext = 'upcoming';
        this.interviewForm = {
            Id: ui.id,
            Application__c: ui.applicationId,
            Interview_Type__c: ui.interviewType || '',
            Scheduled_Date__c: dateVal,
            Status__c: ui.status || 'Scheduled',
            Round__c: ui.round || 1,
            Duration_Minutes__c: ui.durationMinutes || 60,
            Location__c: ui.location || '',
            Notes__c: ui.notes || '',
            Interviewer__c: ui.interviewerId || '',
            Interviewer_2__c: ui.interviewer2Id || ''
        };
        this.editingInterviewJobTitle = ui.jobTitle || '';
        this.showUpcomingEditModal = true;
        this.showInterviewForm = true;
    }

    handleCloseUpcomingEdit() {
        this.showUpcomingEditModal = false;
        this.showInterviewForm = false;
        this.interviewForm = {};
        this.interviewFormContext = '';
    }

    handleJobCardClick(event) {
        const jobId = event.currentTarget.dataset.id;
        this.selectedPipelineJobId = jobId;
        this.activeTab = 'pipeline';
        this._loadPipeline(jobId);
    }

    // ─── Job Modal handlers ───
    handleNewJob() {
        this.jobForm = {
            Title__c: '',
            Department__c: '',
            Location__c: '',
            Job_Type__c: 'Full-time',
            Status__c: 'Open',
            Priority__c: 'Medium',
            Description__c: '',
            Requirements__c: '',
            Number_of_Openings__c: 1,
            Salary_Min__c: null,
            Salary_Max__c: null
        };
        this.showJobModal = true;
    }

    handleEditJob(event) {
        event.stopPropagation();
        const jobId = event.currentTarget.dataset.id;
        const item = this.dashboardData.find(d => d.job.Id === jobId);
        if (item) {
            this.jobForm = {
                Id: item.job.Id,
                Title__c: item.job.Title__c || '',
                Department__c: item.job.Department__c || '',
                Location__c: item.job.Location__c || '',
                Job_Type__c: item.job.Job_Type__c || 'Full-time',
                Status__c: item.job.Status__c || 'Open',
                Priority__c: item.job.Priority__c || 'Medium',
                Description__c: item.job.Description__c || '',
                Requirements__c: item.job.Requirements__c || '',
                Number_of_Openings__c: item.job.Number_of_Openings__c || 1,
                Salary_Min__c: item.job.Salary_Min__c || null,
                Salary_Max__c: item.job.Salary_Max__c || null
            };
            this.showJobModal = true;
        }
    }

    handleJobFormChange(event) {
        const field = event.target.dataset.field;
        let value = event.target.value;
        if (event.target.type === 'number' && value !== '') {
            value = Number(value);
        }
        this.jobForm = { ...this.jobForm, [field]: value };
    }

    handleJobFormComboChange(event) {
        const field = event.target.dataset.field;
        this.jobForm = { ...this.jobForm, [field]: event.detail.value };
    }

    handleCloseJobModal() {
        this.showJobModal = false;
        this.jobForm = {};
    }

    async handleSaveJob() {
        if (!this.jobForm.Title__c) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Missing Information',
                message: 'Job title is required.',
                variant: 'warning'
            }));
            return;
        }

        this.isSavingJob = true;
        try {
            await saveJob({ jobJson: JSON.stringify(this.jobForm) });

            this.dispatchEvent(new ShowToastEvent({
                title: this.isEditingJob ? 'Job Updated' : 'Job Created',
                message: `${this.jobForm.Title__c} has been ${this.isEditingJob ? 'updated' : 'created'} successfully.`,
                variant: 'success'
            }));

            this.showJobModal = false;
            this.jobForm = {};

            await Promise.all([
                refreshApex(this.wiredDashboardResult),
                refreshApex(this.wiredOpenJobsResult)
            ]);
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : 'Failed to save job.',
                variant: 'error'
            }));
        } finally {
            this.isSavingJob = false;
        }
    }

    // ─── New Candidate handlers ───
    _readFileAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve(reader.result.split(',')[1]);
            reader.onerror = () => reject(new Error('Failed to read file'));
            reader.readAsDataURL(file);
        });
    }

    async handleFileChange(event) {
        const file = event.target.files[0];
        console.log('[ATS] handleFileChange called, file:', file?.name, file?.type, file?.size);
        if (!file) return;

        const isPdf = file.type === 'application/pdf' ||
                      file.type === 'application/x-pdf' ||
                      file.name?.toLowerCase().endsWith('.pdf');

        if (!isPdf) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Please upload a PDF file.',
                variant: 'error'
            }));
            return;
        }

        this.pdfFileName = file.name;
        this.pdfFileSizeBytes = file.size;
        this.fileReady = false;
        this.parsedData = {};
        this.showParsedData = false;
        this.parseSuccess = false;
        this.parseError = false;
        this.createSuccess = false;

        try {
            this.base64Pdf = await this._readFileAsBase64(file);
            console.log('[ATS] File read OK, base64 length:', this.base64Pdf?.length);
            this.fileReady = true;
            console.log('[ATS] fileReady set to true');
        } catch (err) {
            console.error('[ATS] File read error:', err);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Failed to read file.',
                variant: 'error'
            }));
        }
    }

    handleDropZoneDragOver(event) {
        event.preventDefault();
        event.currentTarget.classList.add('drag-active');
    }

    handleDropZoneDragLeave(event) {
        event.currentTarget.classList.remove('drag-active');
    }

    async handleDropZoneDrop(event) {
        event.preventDefault();
        event.currentTarget.classList.remove('drag-active');
        const file = event.dataTransfer.files[0];
        const isPdf = file && (file.type === 'application/pdf' ||
                               file.type === 'application/x-pdf' ||
                               file.name?.toLowerCase().endsWith('.pdf'));
        if (isPdf) {
            this.pdfFileName = file.name;
            this.pdfFileSizeBytes = file.size;
            this.fileReady = false;
            this.parsedData = {};
            this.showParsedData = false;
            this.parseSuccess = false;
            this.parseError = false;
            this.createSuccess = false;

            try {
                this.base64Pdf = await this._readFileAsBase64(file);
                console.log('[ATS] Drop file read OK, base64 length:', this.base64Pdf?.length);
                this.fileReady = true;
            } catch (err) {
                console.error('[ATS] Drop file read error:', err);
            }
        }
    }

    async handleParseCv() {
        this.isParsing = true;
        this.parseSuccess = false;
        this.parseError = false;
        this.errorMessage = '';

        try {
            const result = await parseCvFromUpload({ base64Pdf: this.base64Pdf });
            this.parsedData = result;
            this.showParsedData = true;
            this.parseSuccess = true;
        } catch (error) {
            this.parseError = true;
            this.errorMessage = error.body ? error.body.message : 'An unexpected error occurred.';
        } finally {
            this.isParsing = false;
        }
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        this.parsedData = { ...this.parsedData, [field]: value };
    }

    handleJobSelect(event) {
        this.selectedJobId = event.detail.value;
    }

    handleSourceSelect(event) {
        this.selectedSource = event.detail.value;
    }

    async handleCreateCandidate() {
        if (!this.showParsedData) return;

        if (!this.parsedData.firstName || !this.parsedData.lastName) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Missing Information',
                message: 'First name and last name are required.',
                variant: 'warning'
            }));
            return;
        }

        this.isCreating = true;
        try {
            const contactId = await createCandidateWithApplication({
                parsedDataJson: JSON.stringify(this.parsedData),
                jobId: this.selectedJobId || null,
                source: this.selectedSource,
                base64Pdf: this.base64Pdf,
                fileName: this.pdfFileName
            });

            this.createSuccess = true;
            this.createdContactId = contactId;

            this.dispatchEvent(new ShowToastEvent({
                title: 'Candidate Created',
                message: `${this.parsedData.firstName} ${this.parsedData.lastName} has been added successfully.`,
                variant: 'success'
            }));

            await Promise.all([
                refreshApex(this.wiredDashboardResult),
                refreshApex(this.wiredOpenJobsResult)
            ]);
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : 'Failed to create candidate.',
                variant: 'error'
            }));
        } finally {
            this.isCreating = false;
        }
    }

    handleNewCandidate() {
        this.parsedData = {};
        this.showParsedData = false;
        this.base64Pdf = null;
        this.fileReady = false;
        this.pdfFileName = '';
        this.pdfFileSizeBytes = 0;
        this.parseSuccess = false;
        this.parseError = false;
        this.createSuccess = false;
        this.createdContactId = null;
        this.selectedJobId = '';
        this.selectedSource = 'LinkedIn';
    }

    handleViewContact() {
        if (this.createdContactId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.createdContactId,
                    objectApiName: 'Contact',
                    actionName: 'view'
                }
            });
        }
    }

    // ─── Candidates handlers ───
    async _loadCandidates() {
        const searchId = ++this._candidateSearchId;
        this.candidatesLoading = true;
        try {
            const result = await getCandidates({ searchTerm: this.candidateSearchTerm });
            // Ignore stale results from previous searches
            if (searchId !== this._candidateSearchId) return;
            this.candidatesList = this._processCandidates(result);
            this.candidatesLoaded = true;
        } catch (error) {
            if (searchId !== this._candidateSearchId) return;
            console.error('Failed to load candidates:', error);
            const msg = error.body ? error.body.message : 'Failed to load candidates.';
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: msg,
                variant: 'error'
            }));
        } finally {
            if (searchId === this._candidateSearchId) {
                this.candidatesLoading = false;
            }
        }
    }

    _processCandidates(rawList) {
        return (rawList || []).map(c => {
            const skillsArr = c.skills ? c.skills.split('; ').filter(Boolean) : [];
            const langsArr = c.languages ? c.languages.split('; ').filter(Boolean) : [];
            const maxSkills = 5;
            return {
                ...c,
                initials: this._getInitials(c.name),
                skillTags: skillsArr.slice(0, maxSkills),
                hasSkillTags: skillsArr.length > 0,
                moreSkillsCount: skillsArr.length > maxSkills ? skillsArr.length - maxSkills : 0,
                allSkillTags: skillsArr,
                allLanguageTags: langsArr,
                formattedDate: c.createdDate ? new Date(c.createdDate).toLocaleDateString() : '',
                sourceBadgeClass: 'clc-source-badge source-' + (c.candidateSource || 'other').toLowerCase().replace(/\s+/g, '-')
            };
        });
    }

    handleCandidateSearch(event) {
        const value = event.target.value;
        this.candidateSearchTerm = value;
        clearTimeout(this._candidateSearchTimeout);
        this._candidateSearchTimeout = setTimeout(() => {
            this._loadCandidates();
        }, 300);
    }

    handleCandidateCardClick(event) {
        const candidateId = event.currentTarget.dataset.id;
        const cand = this.candidatesList.find(c => c.contactId === candidateId);
        if (cand) {
            this.selectedCandidate = { ...cand };
            this.assignJobId = '';
            this.assignSource = cand.candidateSource || 'LinkedIn';
            this.showCandidateModal = true;
            this.showInterviewForm = false;
            this._loadCandidateInterviews(candidateId);
        }
    }

    handleCloseCandidateModal() {
        this.showCandidateModal = false;
        this.selectedCandidate = {};
        this.candidateInterviews = [];
        this.candidateApplications = [];
        this.showInterviewForm = false;
        this.interviewFormContext = '';
    }

    handleAssignJobSelect(event) {
        this.assignJobId = event.detail.value;
    }

    handleAssignSourceSelect(event) {
        this.assignSource = event.detail.value;
    }

    async handleAssignToJob() {
        if (!this.assignJobId || !this.selectedCandidate.contactId) return;

        this.isAssigning = true;
        try {
            await assignCandidateToJob({
                contactId: this.selectedCandidate.contactId,
                jobId: this.assignJobId,
                source: this.assignSource
            });

            const jobLabel = this.openJobs.find(j => j.Id === this.assignJobId)?.Title__c || 'job';
            this.dispatchEvent(new ShowToastEvent({
                title: 'Assigned',
                message: `${this.selectedCandidate.name} assigned to ${jobLabel}`,
                variant: 'success'
            }));

            this.assignJobId = '';

            // Reload candidates to update application count
            await this._loadCandidates();
            const updated = this.candidatesList.find(c => c.contactId === this.selectedCandidate.contactId);
            if (updated) this.selectedCandidate = { ...updated };

            // Reload interviews (new application now available)
            await this._loadCandidateInterviews(this.selectedCandidate.contactId);

            await refreshApex(this.wiredDashboardResult);
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : 'Failed to assign candidate.',
                variant: 'error'
            }));
        } finally {
            this.isAssigning = false;
        }
    }

    handleViewCandidateRecord() {
        if (this.selectedCandidate.contactId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.selectedCandidate.contactId,
                    objectApiName: 'Contact',
                    actionName: 'view'
                }
            });
        }
    }

    handleViewInCandidates() {
        this.activeTab = 'candidates';
        this.candidatesLoaded = false;
        this._loadCandidates();
    }

    handleGoToNewCandidate() {
        this.activeTab = 'newCandidate';
        this.handleNewCandidate();
    }

    // ─── Candidate Interview handlers ───
    async _loadCandidateInterviews(contactId) {
        this.candidateInterviewsLoading = true;
        try {
            const data = await getInterviewsByCandidate({ contactId });
            this.candidateApplications = data.applications || [];
            this.candidateInterviews = (data.interviews || []).map(iv => {
                const names = [iv.interviewerName, iv.interviewer2Name].filter(Boolean);
                return {
                    ...iv,
                    formattedDate: iv.scheduledDate ? new Date(iv.scheduledDate).toLocaleString() : '',
                    statusBadgeClass: 'pd-iv-status status-' + (iv.status || 'scheduled').toLowerCase().replace(/\s+/g, '-'),
                    interviewersDisplay: names.length > 0 ? names.join(', ') : '',
                    hasInterviewers: names.length > 0
                };
            });
        } catch (error) {
            console.error('Failed to load candidate interviews:', error);
        } finally {
            this.candidateInterviewsLoading = false;
        }
    }

    handleShowCandidateInterviewForm() {
        this.interviewFormContext = 'candidate';
        const firstApp = this.candidateApplications.length > 0 ? this.candidateApplications[0].applicationId : '';
        this.interviewForm = {
            Application__c: firstApp,
            Interview_Type__c: 'Video Call',
            Scheduled_Date__c: '',
            Status__c: 'Scheduled',
            Round__c: this.candidateInterviews.length + 1,
            Duration_Minutes__c: 60,
            Location__c: '',
            Notes__c: '',
            Interviewer__c: '',
            Interviewer_2__c: ''
        };
        this.editingInterviewJobTitle = '';
        this.showInterviewForm = true;
    }

    // ─── Pipeline handlers ───
    handlePipelineJobSelect(event) {
        const jobId = event.detail.value;
        this.selectedPipelineJobId = jobId;
        if (jobId) {
            this._loadPipeline(jobId);
        } else {
            this.pipelineApplications = [];
            this.pipelineStats = null;
        }
    }

    async _loadPipeline(jobId) {
        this.pipelineLoading = true;
        try {
            const [apps, stats] = await Promise.all([
                getApplicationsByJob({ jobId }),
                getPipelineStats({ jobId })
            ]);
            this.pipelineApplications = apps;
            this.pipelineStats = stats;
        } catch (error) {
            console.error('Pipeline load error:', error);
        } finally {
            this.pipelineLoading = false;
        }
    }

    handleDragStart(event) {
        this._didDrag = true;
        this.draggedApplicationId = event.currentTarget.dataset.id;
        event.currentTarget.classList.add('dragging');
    }

    handleDragOver(event) {
        event.preventDefault();
        event.currentTarget.classList.add('drag-over');
    }

    handleDragLeave(event) {
        event.currentTarget.classList.remove('drag-over');
    }

    async handleDrop(event) {
        event.preventDefault();
        const column = event.currentTarget;
        column.classList.remove('drag-over');
        const newStage = column.dataset.stage;

        if (!this.draggedApplicationId || !newStage) return;

        // Check if stage actually changed
        const currentApp = this.pipelineApplications.find(a => a.id === this.draggedApplicationId);
        if (!currentApp || currentApp.stage === newStage) {
            this.template.querySelectorAll('.dragging').forEach(el => el.classList.remove('dragging'));
            this.draggedApplicationId = null;
            return;
        }

        this.template.querySelectorAll('.dragging').forEach(el => el.classList.remove('dragging'));

        // Optimistic update — move card immediately in the UI
        this.pipelineApplications = this.pipelineApplications.map(a =>
            a.id === this.draggedApplicationId ? { ...a, stage: newStage, daysInStage: 0 } : a
        );

        const draggedId = this.draggedApplicationId;
        this.draggedApplicationId = null;

        try {
            await updateApplicationStage({
                applicationId: draggedId,
                newStage
            });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Updated',
                message: `Candidate moved to ${newStage}`,
                variant: 'success'
            }));

            await refreshApex(this.wiredDashboardResult);
        } catch (error) {
            // Revert on error — reload fresh data
            await this._loadPipeline(this.selectedPipelineJobId);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : 'Failed to update stage.',
                variant: 'error'
            }));
        }
    }

    // ─── Pipeline Detail / Interview handlers ───
    handlePipelineCardClick(event) {
        // Ignore click if user just dragged
        if (this._didDrag) {
            this._didDrag = false;
            return;
        }
        const appId = event.currentTarget.dataset.id;
        this._loadApplicationDetail(appId);
    }

    async _loadApplicationDetail(applicationId) {
        this.showPipelineDetailModal = true;
        this.pipelineDetailLoading = true;
        this.showInterviewForm = false;
        try {
            const detail = await getApplicationDetail({ applicationId });
            this.pipelineDetail = this._processApplicationDetail(detail);
        } catch (error) {
            console.error('Failed to load application detail:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Failed to load application details.',
                variant: 'error'
            }));
            this.showPipelineDetailModal = false;
        } finally {
            this.pipelineDetailLoading = false;
        }
    }

    _processApplicationDetail(detail) {
        const stageLower = (detail.stage || 'new').toLowerCase();
        return {
            ...detail,
            initials: this._getInitials(detail.candidateName),
            formattedAppliedDate: detail.appliedDate ? new Date(detail.appliedDate).toLocaleDateString() : '',
            stageBadgeClass: 'pd-stage-badge stage-' + stageLower,
            interviewCount: detail.interviews ? detail.interviews.length : 0,
            hasInterviews: detail.interviews && detail.interviews.length > 0,
            interviews: (detail.interviews || []).map(iv => {
                const names = [iv.interviewerName, iv.interviewer2Name].filter(Boolean);
                return {
                    ...iv,
                    formattedDate: iv.scheduledDate ? new Date(iv.scheduledDate).toLocaleString() : '',
                    statusBadgeClass: 'pd-iv-status status-' + (iv.status || 'scheduled').toLowerCase().replace(/\s+/g, '-'),
                    interviewersDisplay: names.length > 0 ? names.join(', ') : '',
                    hasInterviewers: names.length > 0
                };
            })
        };
    }

    handleClosePipelineDetail() {
        this.showPipelineDetailModal = false;
        this.pipelineDetail = {};
        this.showInterviewForm = false;
        this.interviewFormContext = '';
    }

    async handleRatingClick(event) {
        const rating = parseInt(event.currentTarget.dataset.rating, 10);
        if (!this.pipelineDetail.applicationId) return;

        try {
            await updateApplicationRating({
                applicationId: this.pipelineDetail.applicationId,
                rating
            });
            this.pipelineDetail = { ...this.pipelineDetail, overallRating: rating };

            // Refresh pipeline
            await this._loadPipeline(this.selectedPipelineJobId);
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Failed to update rating.',
                variant: 'error'
            }));
        }
    }

    handleShowInterviewForm() {
        this.interviewFormContext = 'pipeline';
        const nextRound = this.pipelineDetail.interviews
            ? this.pipelineDetail.interviews.length + 1
            : 1;
        this.interviewForm = {
            Application__c: this.pipelineDetail.applicationId,
            Interview_Type__c: 'Video Call',
            Scheduled_Date__c: '',
            Status__c: 'Completed',
            Round__c: nextRound,
            Duration_Minutes__c: 60,
            Location__c: '',
            Notes__c: '',
            Interviewer__c: '',
            Interviewer_2__c: ''
        };
        this.editingInterviewJobTitle = '';
        this.showInterviewForm = true;
    }

    handleCancelInterview() {
        this.showInterviewForm = false;
        this.interviewForm = {};
    }

    handleInterviewFormChange(event) {
        const field = event.target.dataset.field;
        let value = event.target.value;
        if (event.target.type === 'number' && value !== '') {
            value = Number(value);
        }
        this.interviewForm = { ...this.interviewForm, [field]: value };
    }

    handleInterviewFormCombo(event) {
        const field = event.target.dataset.field;
        this.interviewForm = { ...this.interviewForm, [field]: event.detail.value };
    }

    async handleSaveInterview() {
        if (!this.interviewForm.Interview_Type__c || !this.interviewForm.Scheduled_Date__c) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Missing Information',
                message: 'Interview type and date are required.',
                variant: 'warning'
            }));
            return;
        }

        if (!this.interviewForm.Application__c) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Missing Information',
                message: 'Please select a job/application.',
                variant: 'warning'
            }));
            return;
        }

        this.isSavingInterview = true;
        try {
            await saveInterview({ interviewJson: JSON.stringify(this.interviewForm) });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Interview Saved',
                message: `${this.interviewForm.Interview_Type__c} interview saved successfully.`,
                variant: 'success'
            }));

            this.showInterviewForm = false;
            this.interviewForm = {};

            // Reload depending on context
            if (this.interviewFormContext === 'pipeline' && this.pipelineDetail.applicationId) {
                const detail = await getApplicationDetail({
                    applicationId: this.pipelineDetail.applicationId
                });
                this.pipelineDetail = this._processApplicationDetail(detail);
            }
            if (this.interviewFormContext === 'candidate' && this.selectedCandidate.contactId) {
                await this._loadCandidateInterviews(this.selectedCandidate.contactId);
            }
            if (this.interviewFormContext === 'upcoming') {
                this.showUpcomingEditModal = false;
            }

            // Refresh upcoming interviews on dashboard
            await refreshApex(this.wiredUpcomingResult);
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : 'Failed to save interview.',
                variant: 'error'
            }));
        } finally {
            this.isSavingInterview = false;
        }
    }

    handleEditInterview(event) {
        event.stopPropagation();
        const ivId = event.currentTarget.dataset.id;

        // Find the interview in either context
        let iv = null;
        let context = '';

        if (this.showPipelineDetailModal && this.pipelineDetail.interviews) {
            iv = this.pipelineDetail.interviews.find(i => i.id === ivId);
            if (iv) context = 'pipeline';
        }
        if (!iv && this.showCandidateModal && this.candidateInterviews) {
            iv = this.candidateInterviews.find(i => i.id === ivId);
            if (iv) context = 'candidate';
        }

        if (!iv) return;

        this.interviewFormContext = context;
        this.editingInterviewJobTitle = iv.jobTitle || '';

        // Convert scheduledDate back to datetime-local format
        let dateVal = '';
        if (iv.scheduledDate) {
            const d = new Date(iv.scheduledDate);
            dateVal = d.toISOString().slice(0, 16);
        }

        this.interviewForm = {
            Id: iv.id,
            Application__c: iv.applicationId || (context === 'pipeline' ? this.pipelineDetail.applicationId : ''),
            Interview_Type__c: iv.interviewType || '',
            Scheduled_Date__c: dateVal,
            Status__c: iv.status || 'Scheduled',
            Round__c: iv.round || 1,
            Duration_Minutes__c: iv.durationMinutes || 60,
            Location__c: iv.location || '',
            Notes__c: iv.notes || '',
            Interviewer__c: iv.interviewerId || '',
            Interviewer_2__c: iv.interviewer2Id || ''
        };
        this.showInterviewForm = true;
    }

    async handleDeleteInterview(event) {
        event.stopPropagation();
        const ivId = event.currentTarget.dataset.id;

        try {
            await deleteInterview({ interviewId: ivId });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Deleted',
                message: 'Interview has been deleted.',
                variant: 'success'
            }));

            // Reload depending on which modal is open
            if (this.showPipelineDetailModal && this.pipelineDetail.applicationId) {
                const detail = await getApplicationDetail({
                    applicationId: this.pipelineDetail.applicationId
                });
                this.pipelineDetail = this._processApplicationDetail(detail);
            }
            if (this.showCandidateModal && this.selectedCandidate.contactId) {
                await this._loadCandidateInterviews(this.selectedCandidate.contactId);
            }

            await refreshApex(this.wiredUpcomingResult);
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : 'Failed to delete interview.',
                variant: 'error'
            }));
        }
    }

    handleViewApplicationRecord() {
        if (this.pipelineDetail.candidateId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.pipelineDetail.candidateId,
                    objectApiName: 'Contact',
                    actionName: 'view'
                }
            });
        }
    }

    // ─── Utility ───
    _getInitials(name) {
        if (!name) return '?';
        const parts = name.split(' ');
        if (parts.length >= 2) {
            return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
        }
        return parts[0][0].toUpperCase();
    }

    _getStars(rating) {
        const stars = [];
        for (let i = 1; i <= 5; i++) {
            stars.push({
                index: i,
                class: i <= Math.round(rating || 0) ? 'star filled' : 'star empty'
            });
        }
        return stars;
    }
}
