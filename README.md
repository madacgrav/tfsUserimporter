# tfsUserimporter
A tool that can export user account information (ie group memberships) from On Prem ADS and import into ADO


In the rare event where you need to migrate an instance of Azure DevOps Server (Onprem) to Azure DevOps (cloud) NOT using the same domain this script will assist with duplicating permissions from ADS to ADO.


Requirements:
1. Creation of an identity mapping (csv file) with the following information:
   a. Previous domain name with username in the following format.  ie Domain\username
   b. Email address of the same user in Azure Active. ie adam.graves@azuredomain.com
   c. Display name of the same user
2. Project Administrator access to both ADS and ADO
3. Creation of a PAT for ADS and ADO
4. Remote adminstrator access to the ADS onprem server.
5. Knowledge of the version of ADS.
6. Powershell installed on server

Parameters:
domainName : first part of information found in the requirements ie **Domain**\username
ADSPAT : Authentication token created in the ADS server with admin privileges
ADSVersion : The major version of ADS. Allowed values 2019, 2020, 2022
ADSCollectionUrl : The root url for the ADS project collection
ADOorgName : The name of the organization for the ADO instance - ie https://dev.azure.com/**Orgname**
ADOpat : Authentication token created in the ADO instaance with admin privileges

Steps:
Run script with the following parameters
.\Import-UsersADStoADO.ps1 -domainName <domain> -ADSPAT <token for ADS> -ADSVersion 2019 -ADSCollectionUrl "https://ads.domainname.com/tfs/DefaultCollection" -ADOorgName "Orgname" -ADOpat <token for ADO>
