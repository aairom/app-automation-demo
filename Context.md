Build a sample application written in the programming language you find best adapated for the use case.

The application: A "Memeber Management" application uisng SQLite m for member management a table containing "LastName", "FirstName", DateOfBirth", "Username" and "Password" and "Secrets". Create 5 random records and give the capacity to create, update or delete records in the database through the UI.

The security of passwords and secrets managed by HAshicorp Vault.

The application should have Dockerfiles to be deployed on Kuberetes clusters.

There should be Terraform scripts  in "Terraform" folder provided for deployment on a Minikube cluster as example, and SQLite provisioning.

The application should implement OTel for OpenTelemetry metrics visible through Grafana and Prometheus dashboards.

Sample Ansible yaml/scripts should be provided for lifecycle management of the application and infrastructure in "Ansible" folder.

I need a script to lauch the application in detached mode (which should not use Port 5000) and a script to stop the app. Create all scripts for lauching and stopping the application in the "scripts" folder.

Create all dcoumentation in the "Docs" folder. I need also full mermaid architecture documents.

All the manifests should be created in "k8s" folder.

If the application, script or the documentation needs to be updated, update the existing documents and scripts. Don't create new ones each time.

You should refer to this "Context" document each time you need to checkout the guidelines.

GitHub: provide a script in "scripts" folder to initiate and push the application to GitHub. The script should be flawless and don't do you usual error which is waiting for an input. Update the current documents if needed. The only parameters needed for the script are the URL for github repository and the commit comments. In the  .gitignore" file put a filter so the folder's name begining with "_" (Underscore) will not be pushed to GitHub.

Remove everything: provide a script which would cleanup and remove all Docker images downloaded and update the existing documents.



