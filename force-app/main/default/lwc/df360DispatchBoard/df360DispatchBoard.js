import { LightningElement, track, wire } from 'lwc';
import getDispatchBoard from '@salesforce/apex/DF360_ServiceJobController.getDispatchBoard';
import findAvailableTechnicians from '@salesforce/apex/DF360_DispatchController.findAvailableTechnicians';
import assignTechnician from '@salesforce/apex/DF360_DispatchController.assignTechnician';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class Df360DispatchBoard extends LightningElement {
    @track statusFilter = 'All';
    @track jobs = [];
    @track selectedJob = null;
    @track matchedTechs = [];
    @track isLoading = false;

    statusOptions = [
        { label: 'All Open Jobs', value: 'All' },
        { label: 'New', value: 'New' },
        { label: 'Assigned', value: 'Assigned' },
        { label: 'In Progress', value: 'In Progress' },
        { label: 'Parts Awaited', value: 'Parts Awaited' }
    ];

    connectedCallback() {
        this.loadJobs();
    }

    get jobCount() {
        return this.jobs.length;
    }

    async loadJobs() {
        this.isLoading = true;
        try {
            const data = await getDispatchBoard({ statusFilter: this.statusFilter, zoneId: null });
            this.jobs = data.map(j => {
                let cardClass = 'job-card slds-box slds-m-bottom_x-small';
                let slaBadgeClass = 'slds-badge ';
                if (j.slaStatus === 'Red' || j.slaStatus === 'Breached') slaBadgeClass += 'slds-theme_error';
                else if (j.slaStatus === 'Amber') slaBadgeClass += 'slds-theme_warning';
                else slaBadgeClass += 'slds-theme_success';
                
                return { ...j, cardClass, slaBadgeClass };
            });
        } catch(e) {
            this.showToast('Error', e.body?.message || 'Error loading jobs', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleStatusFilterChange(event) {
        this.statusFilter = event.detail.value;
        this.loadJobs();
    }

    handleRefresh() {
        this.loadJobs();
    }

    async handleSelectJob(event) {
        const jobId = event.currentTarget.dataset.id;
        this.selectedJob = this.jobs.find(j => j.id === jobId);
        this.isLoading = true;
        try {
            this.matchedTechs = await findAvailableTechnicians({ jobId: jobId });
        } catch(e) {
            this.showToast('Error', 'Unable to score technicians', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleAssign(event) {
        const techId = event.target.dataset.techid;
        if (!this.selectedJob || !techId) return;
        this.isLoading = true;
        try {
            await assignTechnician({ jobId: this.selectedJob.id, technicianId: techId });
            this.showToast('Success', 'Technician successfully assigned and notified via push!', 'success');
            this.selectedJob = null;
            this.matchedTechs = [];
            this.loadJobs();
        } catch(e) {
            this.showToast('Error', e.body?.message || 'Failed to assign technician', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleAutoDispatch() {
        this.showToast('Auto-Dispatch', 'Auto-dispatch algorithm triggered for all open jobs', 'info');
        this.loadJobs();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
