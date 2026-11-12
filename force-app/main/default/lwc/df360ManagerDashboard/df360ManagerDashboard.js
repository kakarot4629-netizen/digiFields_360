import { LightningElement, track, wire } from 'lwc';
import getManagerDashboard from '@salesforce/apex/DF360_AnalyticsController.getManagerDashboard';
import getSLACompliance from '@salesforce/apex/DF360_AnalyticsController.getSLACompliance';

export default class Df360ManagerDashboard extends LightningElement {
    @track metrics = { jobsToday: 0, completed: 0, ftfr: 0, ftfrPct: 0, csatAvg: 0, partsPending: 0, slaGreen: 0, slaAmber: 0, slaRed: 0 };
    @track slaReport = { total: 0, breached: 0, compliance: 100 };

    connectedCallback() {
        this.loadDashboard();
    }

    async loadDashboard() {
        try {
            const data = await getManagerDashboard({ zoneId: null });
            if (data) this.metrics = data;
            const sla = await getSLACompliance({ zoneId: null, days: 30 });
            if (sla) this.slaReport = sla;
        } catch(e) {
            console.error('Error loading dashboard:', e);
        }
    }

    get greenWidth() {
        const total = (this.metrics.slaGreen || 0) + (this.metrics.slaAmber || 0) + (this.metrics.slaRed || 0) || 1;
        return `width: ${((this.metrics.slaGreen || 0)/total * 100).toFixed(0)}%`;
    }
    get amberWidth() {
        const total = (this.metrics.slaGreen || 0) + (this.metrics.slaAmber || 0) + (this.metrics.slaRed || 0) || 1;
        return `width: ${((this.metrics.slaAmber || 0)/total * 100).toFixed(0)}%`;
    }
    get redWidth() {
        const total = (this.metrics.slaGreen || 0) + (this.metrics.slaAmber || 0) + (this.metrics.slaRed || 0) || 1;
        return `width: ${((this.metrics.slaRed || 0)/total * 100).toFixed(0)}%`;
    }
}
