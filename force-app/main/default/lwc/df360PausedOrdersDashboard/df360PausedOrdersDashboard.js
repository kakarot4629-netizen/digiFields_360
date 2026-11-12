import { LightningElement, track } from 'lwc';
import getPausedWorkOrdersDashboard from '@salesforce/apex/DF360_WorkOrderPauseController.getPausedWorkOrdersDashboard';

export default class Df360PausedOrdersDashboard extends LightningElement {
    @track isLoading = false;
    @track totalPaused = 0;
    @track overdueCount = 0;
    @track partsCount = 0;
    @track accessCount = 0;
    @track records = [];
    @track filterKeyword = '';

    connectedCallback() {
        this.loadDashboard();
    }

    async loadDashboard() {
        this.isLoading = true;
        try {
            const data = await getPausedWorkOrdersDashboard();
            this.totalPaused = data.totalPaused || 0;
            this.overdueCount = data.overdueCount || 0;

            const byReason = data.reasonCount || {};
            this.partsCount = byReason['Waiting for Part'] || 0;
            this.accessCount = (byReason['Waiting for Customer'] || 0) + (byReason['Waiting for Site Access'] || 0);

            this.records = data.records || [];
        } catch (error) {
            console.error('Error loading paused dashboard:', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleFilterInput(event) {
        this.filterKeyword = (event.target.value || '').toLowerCase();
    }

    get filteredRecords() {
        if (!this.filterKeyword) return this.records;
        return this.records.filter(r =>
            (r.name && r.name.toLowerCase().includes(this.filterKeyword)) ||
            (r.subject && r.subject.toLowerCase().includes(this.filterKeyword)) ||
            (r.reason && r.reason.toLowerCase().includes(this.filterKeyword)) ||
            (r.team && r.team.toLowerCase().includes(this.filterKeyword)) ||
            (r.accountName && r.accountName.toLowerCase().includes(this.filterKeyword))
        );
    }
}
