import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getJobDashboard from '@salesforce/apex/ApplicationController.getJobDashboard';

export default class AtsJobDashboard extends LightningElement {
    @track dashboardData = [];
    isLoading = false;
    wiredResult;

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

    @wire(getJobDashboard)
    wiredDashboard(result) {
        this.wiredResult = result;
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
        } else if (result.error) {
            console.error('Dashboard error:', result.error);
        }
    }

    async handleRefresh() {
        this.isLoading = true;
        try {
            await refreshApex(this.wiredResult);
        } finally {
            this.isLoading = false;
        }
    }
}
