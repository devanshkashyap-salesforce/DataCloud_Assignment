import { LightningElement, track } from 'lwc';
import getCustomerData from '@salesforce/apex/CustomerInsightsController.getCustomerData';
import getAIRecommendation from '@salesforce/apex/CustomerInsightsController.getAIRecommendation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CustomerInsights extends LightningElement {
    @track searchId = '';
    @track customerData = null;
    @track recommendation = '';
    @track errorMessage = '';
    @track isLoading = false;
    @track aiLoading = false;
    @track isActivityExpanded = true;

    handleIdChange(event) {
        this.searchId = event.target.value;
    }

    async handleSubmit() {
        if (!this.searchId || !this.searchId.trim()) {
            this.showToast('Validation Error', 'Please enter a valid Visitor / Customer ID.', 'error');
            return;
        }

        this.isLoading = true;
        this.customerData = null;
        this.recommendation = '';
        this.errorMessage = '';

        try {
            const data = await getCustomerData({ customerId: this.searchId.trim() });
            if (data) {
                this.customerData = data;
            }
        } catch (error) {
            console.error('Data Fetch Trace Error: ', error);
            this.errorMessage = error.body?.message || 'Customer does not exist in the system.';
            this.showToast('Data Error', this.errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleGetRecommendation() {
        if (!this.customerData || !this.customerData.FullName) return;

        this.aiLoading = true;
        this.recommendation = '';

        try {
            const aiText = await getAIRecommendation({ fullName: this.customerData.FullName });
            
            if (aiText) {
                // FIXED: Bulletproof JS parsing matches "Agentforce Recommendation:" case-insensitively and drops prior data
                const matchRegex = /Agentforce Recommendation\s*:\s*([\s\S]*)/i;
                const matches = aiText.match(matchRegex);
                
                if (matches && matches[1]) {
                    this.recommendation = matches[1].trim();
                } else {
                    this.recommendation = aiText; // Fallback to raw layout text if format changes unexpectedly
                }
            }
        } catch (error) {
            console.error('Agentforce API Exception: ', error);
            this.showToast('AI Generation Failed', error.body?.message || 'Unable to load prompt action.', 'error');
        } finally {
            this.aiLoading = false;
        }
    }

    toggleActivitySection() {
        this.isActivityExpanded = !this.isActivityExpanded;
    }

    /* ==========================================================================
       DYNAMIC RUNTIME INTERFACE STATE AND ICON COMPUTATIONS
       ========================================================================== */

    get activitiesCount() {
        return this.customerData && this.customerData.activities ? this.customerData.activities.length : 0;
    }

    get toggleButtonLabel() {
        return this.isActivityExpanded ? '[ Hide Section ]' : '[ Expand Section ]';
    }

    get searchButtonLabel() {
        return this.isLoading ? 'Searching...' : 'Get Insights';
    }

    get searchButtonIcon() {
        return this.isLoading ? 'utility:sync' : 'utility:search';
    }

    get aiButtonLabel() {
        return this.aiLoading ? 'Generating...' : 'Get Recommendation';
    }

    get aiButtonIcon() {
        return this.aiLoading ? 'utility:sync' : 'utility:lights';
    }

    get intentIcon() {
        if (!this.customerData || !this.customerData.IntentLevel) return 'utility:info';
        const intent = this.customerData.IntentLevel.toLowerCase();
        
        if (intent.includes('ready') || intent.includes('high') || intent.includes('purchase')) {
            return 'utility:cart';
        } else if (intent.includes('new') || intent.includes('lead')) {
            return 'utility:add';
        } else if (intent.includes('retention') || intent.includes('warning') || intent.includes('warm')) {
            return 'utility:warning';
        }
        return 'utility:info';
    }

    get intentIconVariant() {
        if (!this.customerData || !this.customerData.IntentLevel) return '';
        const intent = this.customerData.IntentLevel.toLowerCase();
        
        if (intent.includes('ready') || intent.includes('high') || intent.includes('purchase')) {
            return 'error'; 
        } else if (intent.includes('new') || intent.includes('lead')) {
            return 'brand'; 
        } else if (intent.includes('retention') || intent.includes('warning') || intent.includes('warm')) {
            return 'warning'; 
        }
        return '';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}