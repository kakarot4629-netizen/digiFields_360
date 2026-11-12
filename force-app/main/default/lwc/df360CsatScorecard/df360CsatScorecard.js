import { LightningElement, api, track } from 'lwc';
import getTechnicianCSAT from '@salesforce/apex/DF360_CSATController.getTechnicianCSAT';

export default class Df360CsatScorecard extends LightningElement {
    @api recordId; // Technician Id
    @track csatData = { avg: 0, records: [] };

    connectedCallback() {
        this.loadCSAT();
    }

    async loadCSAT() {
        try {
            const data = await getTechnicianCSAT({ technicianId: this.recordId, days: 30 });
            if (data && data.length > 0) this.csatData = data[0];
        } catch(e) {
            console.error(e);
        }
    }
}
