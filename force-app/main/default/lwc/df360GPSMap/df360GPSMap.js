import { LightningElement, track } from 'lwc';
import getTeamPositions from '@salesforce/apex/DF360_GPSController.getTeamPositions';

export default class Df360GPSMap extends LightningElement {
    @track techs = [];

    connectedCallback() {
        this.loadPositions();
    }

    async loadPositions() {
        try {
            this.techs = await getTeamPositions({ zoneId: null });
        } catch(e) {
            console.error(e);
        }
    }
}
