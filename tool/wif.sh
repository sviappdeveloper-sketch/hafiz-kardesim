#!/bin/bash
# Bir kerelik kurulum (Google Cloud Shell'de çalıştırılır): GitHub Actions'ın hafiz-kardesim deposunun
# yalnızca main dalından, indirilmiş gizli anahtar olmadan (Workload Identity Federation) Firestore
# kurallarını ve Firebase Hosting'i yayınlayabilmesi için izin.
set -e
P=hatim-kardesim
N=668036405824
REPO=sviappdeveloper-sketch/hafiz-kardesim
SA=github-deploy@$P.iam.gserviceaccount.com
gcloud config set project $P >/dev/null
gcloud services enable iamcredentials.googleapis.com sts.googleapis.com iam.googleapis.com firebasehosting.googleapis.com firebaserules.googleapis.com
gcloud iam workload-identity-pools describe github --location=global >/dev/null 2>&1 || \
  gcloud iam workload-identity-pools create github --location=global --display-name=GitHub
gcloud iam workload-identity-pools providers describe hafiz-repo --location=global --workload-identity-pool=github >/dev/null 2>&1 || \
  gcloud iam workload-identity-pools providers create-oidc hafiz-repo --location=global --workload-identity-pool=github \
    --display-name=hafiz-kardesim --issuer-uri=https://token.actions.githubusercontent.com \
    --attribute-mapping=google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref \
    --attribute-condition="assertion.repository=='$REPO' && assertion.ref=='refs/heads/main'"
gcloud iam service-accounts describe $SA >/dev/null 2>&1 || \
  gcloud iam service-accounts create github-deploy --display-name="GitHub yayin (kurallar + hosting)"
for R in roles/firebaserules.admin roles/firebasehosting.admin roles/serviceusage.serviceUsageConsumer roles/firebase.viewer; do
  gcloud projects add-iam-policy-binding $P --member=serviceAccount:$SA --role=$R --condition=None -q >/dev/null
  echo "rol verildi: $R"
done
gcloud iam service-accounts add-iam-policy-binding $SA --role=roles/iam.workloadIdentityUser \
  --member=principalSet://iam.googleapis.com/projects/$N/locations/global/workloadIdentityPools/github/attribute.repository/$REPO >/dev/null
echo KURULUM_TAMAM
