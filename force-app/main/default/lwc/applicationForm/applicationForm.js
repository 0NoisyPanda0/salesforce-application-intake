import { LightningElement, track } from 'lwc';
import submitApplication from '@salesforce/apex/ApplicationIntakeController.submitApplication';

const INITIAL_FORM = () => ({
    companyName:      '',
    email:            '',
    phone:            '',
    contactFirstName: '',
    contactLastName:  '',
    federalTaxId:     '',
    annualRevenue:    null,
});

export default class ApplicationForm extends LightningElement {

    @track formData    = INITIAL_FORM();
    @track isLoading   = false;
    @track isSuccess   = false;
    @track errorMessage = '';
    @track successMessage = '';

    get submitLabel() {
        return this.isLoading ? 'Submitting…' : 'Submit Application';
    }

    handleFieldChange(event) {
        const { name, value } = event.target;
        this.formData = { ...this.formData, [name]: value };
    }

    async handleSubmit() {
        this.errorMessage = '';

        const allValid = this.runNativeValidation();
        if (!allValid) return;

        this.isLoading = true;

        try {
            const result = await submitApplication({
                payload: { ...this.formData }
            });

            if (result.success) {
                this.isSuccess = true;
                this.successMessage =
                    `Your application was received as a ${result.recordType}. ` +
                    `Reference ID: ${result.recordId}`;
            } else {
                this.errorMessage = result.errorMessage || 'Submission failed. Please try again.';
            }

        } catch (error) {
            this.errorMessage = this.extractErrorMessage(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleReset() {
        this.formData     = INITIAL_FORM();
        this.isSuccess    = false;
        this.errorMessage = '';
        this.successMessage = '';
    }

    runNativeValidation() {
        const inputs = this.template.querySelectorAll('lightning-input');
        let allValid = true;

        inputs.forEach(input => {
            if (!input.reportValidity()) {
                allValid = false;
            }
        });

        return allValid;
    }

    extractErrorMessage(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message)       return error.message;
        return 'An unexpected error occurred. Please contact support.';
    }
}
