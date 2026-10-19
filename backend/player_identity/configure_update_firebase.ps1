$ErrorActionPreference='Stop'
$project='jade-ascendant'
$sender='jade-iap-verifier@jade-ascendant.iam.gserviceaccount.com'
$gcloud=Get-Command gcloud.cmd -ErrorAction SilentlyContinue
if (-not $gcloud) { $gcloud=Get-Command gcloud -ErrorAction SilentlyContinue }
if ($gcloud) {
    & $gcloud.Source services enable fcm.googleapis.com --project $project --quiet
    if ($LASTEXITCODE -eq 0) {
        & $gcloud.Source projects add-iam-policy-binding $project --member "serviceAccount:$sender" --role roles/firebasecloudmessaging.admin --condition=None --quiet
        if ($LASTEXITCODE -eq 0) { Write-Host 'FIREBASE_SETUP_APPLIED=PASS; CHECK_DASHBOARD_VALIDATE_ONLY; BROADCAST=NONE; KEY_ROTATION=NONE'; exit 0 }
    }
}
Write-Host 'FIREBASE_ADMIN_ACTION_REQUIRED: Google project administrator access is needed.'
Write-Host "Project: $project"
Write-Host "Service account: $sender"
Write-Host 'Role: Firebase Cloud Messaging API Admin (roles/firebasecloudmessaging.admin)'
Write-Host 'Enable Firebase Cloud Messaging API, grant that role to this service account, then click Cek koneksi Firebase in the dashboard.'
Start-Process 'https://console.cloud.google.com/apis/library/fcm.googleapis.com?project=jade-ascendant'
Start-Process 'https://console.cloud.google.com/iam-admin/iam?project=jade-ascendant'
# The batch can finish its native/export work while the administrator configures IAM.
exit 0
