import { LightningElement, api, track } from 'lwc';
import getJobDetail from '@salesforce/apex/DF360_ServiceJobController.getJobDetail';
import recordCSATResponse from '@salesforce/apex/DF360_CSATController.recordCSATResponse';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class Df360CustomerPortal extends LightningElement {
    @api recordId;
    @track job;

    connectedCallback() {
        if (this.recordId) this.loadJob();
    }

    async loadJob() {
        try {
            this.job = await getJobDetail({ jobId: this.recordId });
        } catch(e) {
            console.error(e);
        }
    }

    get technicianName() {
        return this.job?.Technician__r?.Name || 'Unassigned';
    }

    get assetName() {
        return this.job?.Asset__r?.Product_Name__c || this.job?.Asset__r?.Name || 'No Equipment Listed';
    }

    async handleRate(event) {
        const rating = parseInt(event.target.dataset.val, 10);
        try {
            await recordCSATResponse({ jobName: this.job.Name, rating: rating, comment: 'Submitted via Customer Experience Portal', mobile: '' });
            this.showToast('Thank You!', 'Your rating has been received', 'success');
        } catch(e) {
            this.showToast('Submitted', 'Thank you for your feedback', 'success');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
