import { LightningElement, track } from "lwc";
import executeNaturalLanguageQuery from "@salesforce/apex/F360_NLQueryController.executeNaturalLanguageQuery";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class Field360NaturalLanguageQuery extends LightningElement {
  @track searchPrompt = "";
  @track isLoading = false;
  @track hasSearched = false;
  @track hasError = false;
  @track errorMessage = "";

  @track targetObjectLabel = "";
  @track generatedSoql = "";
  @track aiSummary = "";
  @track columns = [];
  @track data = [];
  @track recordCount = 0;

  @track showSoql = false;
  @track sortedBy;
  @track sortedDirection = "asc";

  quickPrompts = [
    {
      label: "Top 10 Accounts in Pune",
      text: "Show me top 10 accounts with revenue in Pune",
      icon: "🏢"
    },
    {
      label: "Available Techs in Pune",
      text: "Who are available resources with generator skills in Pune",
      icon: "👨‍🔧"
    },
    {
      label: "Critical Alerts on Generators",
      text: "Show all critical open alerts on generators",
      icon: "🚨"
    },
    {
      label: "Open Critical Work Orders",
      text: "Show all critical open work orders in Pune",
      icon: "📋"
    },
    {
      label: "Biotechnology Clients",
      text: "List all biotechnology companies",
      icon: "🔬"
    },
    {
      label: "HVAC Techs in Mumbai",
      text: "Find active technicians skilled in HVAC in Mumbai",
      icon: "❄️"
    }
  ];

  get hasData() {
    return this.data && this.data.length > 0;
  }

  get recordCountBadgeLabel() {
    return `${this.recordCount} ${this.targetObjectLabel || "Record"}(s) Found`;
  }

  get soqlButtonLabel() {
    return this.showSoql ? "Hide SOQL" : "View SOQL";
  }

  handleInputChange(event) {
    this.searchPrompt = event.target.value;
  }

  handleKeyDown(event) {
    if (event.key === "Enter") {
      this.handleSearch();
    }
  }

  handleQuickPillClick(event) {
    const promptText = event.currentTarget.dataset.prompt;
    this.searchPrompt = promptText;
    this.handleSearch();
  }

  async handleSearch() {
    const prompt = (this.searchPrompt || "").trim();
    if (!prompt) {
      this.showToast(
        "Please enter a query",
        "Type a question or select a quick prompt.",
        "warning"
      );
      return;
    }

    this.isLoading = true;
    this.hasSearched = true;
    this.hasError = false;
    this.errorMessage = "";

    try {
      const result = await executeNaturalLanguageQuery({
        prompt: prompt,
        maxRecords: 15
      });

      if (result && result.isSuccess) {
        this.targetObjectLabel = result.targetObjectLabel;
        this.generatedSoql = result.soql;
        this.aiSummary = result.aiSummary;
        this.recordCount = result.recordCount;
        this.columns = result.columns || [];
        this.data = result.records || [];
      } else {
        this.hasError = true;
        this.errorMessage =
          result?.errorMessage ||
          "An error occurred while executing the query.";
        this.data = [];
      }
    } catch (err) {
      this.hasError = true;
      this.errorMessage =
        err.body?.message || err.message || "Server communication error.";
      this.data = [];
    } finally {
      this.isLoading = false;
    }
  }

  toggleSoql() {
    this.showSoql = !this.showSoql;
  }

  copySoql() {
    if (!this.generatedSoql) return;
    navigator.clipboard
      .writeText(this.generatedSoql)
      .then(() => {
        this.showToast(
          "Copied!",
          "Generated SOQL copied to clipboard.",
          "success"
        );
      })
      .catch(() => {
        this.showToast(
          "Notice",
          "Unable to copy to clipboard automatically.",
          "info"
        );
      });
  }

  handleSort(event) {
    const { fieldName: sortedBy, sortDirection: sortedDirection } =
      event.detail;
    const cloneData = [...this.data];

    cloneData.sort((a, b) => {
      let valA = a[sortedBy];
      let valB = b[sortedBy];
      if (valA === undefined || valA === null) valA = "";
      if (valB === undefined || valB === null) valB = "";

      let reverse = sortedDirection === "asc" ? 1 : -1;
      if (typeof valA === "number" && typeof valB === "number") {
        return (valA - valB) * reverse;
      }
      return String(valA).localeCompare(String(valB)) * reverse;
    });

    this.data = cloneData;
    this.sortedBy = sortedBy;
    this.sortedDirection = sortedDirection;
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
