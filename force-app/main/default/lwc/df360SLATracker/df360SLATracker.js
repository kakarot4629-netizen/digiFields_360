import { LightningElement, api, track } from 'lwc';
import getSLAStatus from '@salesforce/apex/DF360_SLAController.getSLAStatus';
import getSLATimeline from '@salesforce/apex/DF360_SLAController.getSLATimeline';

export default class Df360SLATracker extends LightningElement {
    @api recordId;
    @track slaInfo;
    @track timeline = [];

    connectedCallback() {
        if (this.recordId) this.loadSLA();
    }

    get slaBadgeClass() {
        let base = 'slds-badge slds-p-around_x-small ';
        if (this.slaInfo?.color === 'Breached' || this.slaInfo?.color === 'Red') return base + 'slds-theme_error';
        if (this.slaInfo?.color === 'Amber') return base + 'slds-theme_warning';
        return base + 'slds-theme_success';
    }

    async loadSLA() {
        try {
            this.slaInfo = await getSLAStatus({ jobId: this.recordId });
            this.timeline = await getSLATimeline({ jobId: this.recordId });
        } catch(e) {
            console.error(e);
        }
    }
}
