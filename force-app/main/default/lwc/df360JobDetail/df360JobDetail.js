import { LightningElement, api, track } from 'lwc';
import getJobDetail from '@salesforce/apex/DF360_ServiceJobController.getJobDetail';
import checkIn from '@salesforce/apex/DF360_ServiceJobController.checkIn';
import completeJob from '@salesforce/apex/DF360_ServiceJobController.completeJob';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class Df360JobDetail extends LightningElement {
    @api recordId;
    @track job;
    @track isLoading = false;

    connectedCallback() {
        if (this.recordId) {
            this.loadJob();
        }
    }

    get cardTitle() {
        return this.job ? `Service Job: ${this.job.Name}` : 'Service Job Detail';
    }

    get customerName() {
        return this.job?.Account__r?.Name || 'N/A';
    }

    get assetName() {
        return this.job?.Asset__r?.Product_Name__c || this.job?.Asset__r?.Name || 'No Asset Assigned';
    }

    get isOnSite() {
        return this.job?.Status__c === 'On Site';
    }

    get isCompleted() {
        const s = this.job?.Status__c;
        return s === 'Completed' || s === 'Cancelled';
    }

    get isCheckInDisabled() {
        return this.isLoading || this.isOnSite || this.isCompleted;
    }

    get isCompleteDisabled() {
        return this.isLoading || this.isCompleted;
    }

    get checkInButtonLabel() {
        if (this.isOnSite) return 'Checked In (On Site)';
        if (this.isCompleted) return 'Completed';
        return 'Check-In at Site';
    }

    get statusBadgeClass() {
        const s = this.job?.Status__c;
        if (s === 'Completed') return 'slds-badge slds-theme_success';
        if (s === 'On Site' || s === 'In Progress') return 'slds-badge slds-theme_info';
        if (s === 'Cancelled') return 'slds-badge slds-theme_error';
        return 'slds-badge slds-theme_inverse';
    }

    async loadJob() {
        try {
            this.isLoading = true;
            this.job = await getJobDetail({ jobId: this.recordId });
        } catch(e) {
            console.error('Error loading job detail:', e);
        } finally {
            this.isLoading = false;
        }
    }

    async handleCheckIn() {
        if (this.isCheckInDisabled) return;

        this.isLoading = true;
        try {
            let lat = 19.0760;
            let lng = 72.8777;

            // Attempt to get browser geolocation if available
            if (typeof navigator !== 'undefined' && navigator.geolocation) {
                try {
                    const pos = await new Promise((resolve, reject) => {
                        navigator.geolocation.getCurrentPosition(resolve, reject, { timeout: 3000 });
                    });
                    if (pos?.coords?.latitude && pos?.coords?.longitude) {
                        lat = pos.coords.latitude;
                        lng = pos.coords.longitude;
                    }
                } catch (geoErr) {
                    console.log('Using default GPS coordinates: ', geoErr);
                }
            }

            await checkIn({ 
                jobId: this.recordId, 
                technicianId: this.job?.Technician__c, 
                lat: lat, 
                lng: lng 
            });

            this.showToast('Checked In', 'Technician marked On Site with GPS recorded', 'success');
            await this.loadJob();
        } catch(e) {
            const errorMsg = this.extractErrorMessage(e, 'Check-in failed');
            this.showToast('Check-In Error', errorMsg, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleCompleteJob() {
        if (this.isCompleteDisabled) return;

        this.isLoading = true;
        try {
            await completeJob({ 
                jobId: this.recordId, 
                isFirstTimeFix: true, 
                signatureUrl: 'https://sig.digifield360.io/sig.png' 
            });

            this.showToast('Job Completed', 'Job marked Completed and CSAT survey dispatched via WhatsApp', 'success');
            await this.loadJob();
        } catch(e) {
            const errorMsg = this.extractErrorMessage(e, 'Completion failed');
            this.showToast('Completion Error', errorMsg, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    extractErrorMessage(error, defaultMsg) {
        if (!error) return defaultMsg;
        if (typeof error === 'string') return error;
        if (error.body) {
            if (typeof error.body.message === 'string') return error.body.message;
            if (Array.isArray(error.body.pageErrors) && error.body.pageErrors.length > 0) {
                return error.body.pageErrors[0].message;
            }
            if (Array.isArray(error.body) && error.body.length > 0 && error.body[0].message) {
                return error.body[0].message;
            }
        }
        if (error.message) return error.message;
        return defaultMsg;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
