public class ATSMetadataCallback implements Metadata.DeployCallback {
    public void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {
        if (result.status == Metadata.DeployStatus.Succeeded) {
            System.debug('ATS: Custom metadata deployed successfully');
        } else {
            System.debug('ATS: Custom metadata deployment failed: ' + result.errorMessage);
        }
    }
}
