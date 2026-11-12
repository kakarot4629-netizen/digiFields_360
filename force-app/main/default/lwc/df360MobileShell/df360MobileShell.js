import { LightningElement, track } from 'lwc';
import getTodaysJobs from '@salesforce/apex/DF360_TechnicianController.getTodaysJobs';
import updateAvailability from '@salesforce/apex/DF360_TechnicianController.updateAvailability';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class Df360MobileShell extends LightningElement {
    @track jobs = [];

    connectedCallback() {
        this.loadJobs();
    }

    get jobCount() {
        return this.jobs.length;
    }

    async loadJobs() {
        try {
            this.jobs = await getTodaysJobs({ technicianId: null });
        } catch(e) {
            console.error(e);
        }
    }

    async handleSetAvailable() {
        try {
            await updateAvailability({ technicianId: null, status: 'Available' });
            this.showToast('Status Updated', 'You are now marked Available', 'success');
        } catch(e) {
            this.showToast('Error', 'Update failed', 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
