import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getApplicationsByJob from '@salesforce/apex/ApplicationController.getApplicationsByJob';
import getPipelineStats from '@salesforce/apex/ApplicationController.getPipelineStats';
import updateApplicationStage from '@salesforce/apex/ApplicationController.updateApplicationStage';

const STAGE_CONFIG = [
    { name: 'New', label: 'New', color: '#0176d3', bgColor: '#e8f4fd' },
    { name: 'Screening', label: 'Screening', color: '#9050e9', bgColor: '#f3edff' },
    { name: 'Interview', label: 'Interview', color: '#dd7a01', bgColor: '#fef4e8' },
    { name: 'Evaluation', label: 'Evaluation', color: '#0d9dda', bgColor: '#e5f6fd' },
    { name: 'Offer', label: 'Offer', color: '#2e844a', bgColor: '#e6f7ec' },
    { name: 'Hired', label: 'Hired', color: '#2e844a', bgColor: '#e6f7ec' }
];

export default class CandidatePipeline extends LightningElement {
    @api recordId; // Job__c record Id
    @track applications = [];
    stats;
    isLoading = false;
    draggedApplicationId;

    wiredApplicationsResult;
    wiredStatsResult;

    get jobTitle() {
        if (this.applications && this.applications.length > 0) {
            return this.applications[0].jobTitle;
        }
        return '';
    }

    get totalActive() {
        return this.stats ? this.stats.totalActive : 0;
    }

    get stages() {
        return STAGE_CONFIG.map(stageConfig => {
            const apps = this.applications
                .filter(app => app.stage === stageConfig.name)
                .map(app => ({
                    ...app,
                    initials: this.getInitials(app.candidateName),
                    stars: this.getStars(app.overallRating),
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

    @wire(getApplicationsByJob, { jobId: '$recordId' })
    wiredApplications(result) {
        this.wiredApplicationsResult = result;
        if (result.data) {
            this.applications = result.data;
        } else if (result.error) {
            console.error('Error loading applications:', result.error);
        }
    }

    @wire(getPipelineStats, { jobId: '$recordId' })
    wiredStats(result) {
        this.wiredStatsResult = result;
        if (result.data) {
            this.stats = result.data;
        }
    }

    getInitials(name) {
        if (!name) return '?';
        const parts = name.split(' ');
        if (parts.length >= 2) {
            return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
        }
        return parts[0][0].toUpperCase();
    }

    getStars(rating) {
        const stars = [];
        for (let i = 1; i <= 5; i++) {
            stars.push({
                index: i,
                class: i <= Math.round(rating || 0) ? 'star filled' : 'star empty'
            });
        }
        return stars;
    }

    handleDragStart(event) {
        this.draggedApplicationId = event.currentTarget.dataset.id;
        event.currentTarget.classList.add('dragging');
    }

    handleDragOver(event) {
        event.preventDefault();
        const column = event.currentTarget;
        column.classList.add('drag-over');
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

        // Remove dragging class from all cards
        this.template.querySelectorAll('.dragging').forEach(el => {
            el.classList.remove('dragging');
        });

        try {
            await updateApplicationStage({
                applicationId: this.draggedApplicationId,
                newStage: newStage
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Updated',
                    message: `Candidate moved to ${newStage}`,
                    variant: 'success'
                })
            );

            await Promise.all([
                refreshApex(this.wiredApplicationsResult),
                refreshApex(this.wiredStatsResult)
            ]);
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body ? error.body.message : 'Failed to update stage.',
                    variant: 'error'
                })
            );
        }

        this.draggedApplicationId = null;
    }

    async handleRefresh() {
        this.isLoading = true;
        try {
            await Promise.all([
                refreshApex(this.wiredApplicationsResult),
                refreshApex(this.wiredStatsResult)
            ]);
        } finally {
            this.isLoading = false;
        }
    }
}
