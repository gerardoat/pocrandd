$env = $args[0]
$prj = $args[1]
$loc = $args[2]
$sid = $args[3]

$rgp = $env+'rgp'+$prj
$akv = $env+'akv'+$prj
$acr = $env+'acr'+$prj
$asp = $env+'asp'+$prj
$aks = $env+'aks'+$prj


#az account set --subscription $sid

# Creacion del grupo de recursos
$rgCheck = az group list --query "[?name=='$rgp']" | ConvertFrom-Json
$rgExists = $rgCheck.Length -gt 0
if (!$rgExists){
    az group create --name $rgp --location $loc
}

# Creacion del KeyVault
$kvCheck = az keyvault  list --query "[?name=='$akv']" | ConvertFrom-Json
$kvExists = $kvCheck.Length -gt 0
if (!$kvExists){
    az keyvault create --location $loc --name $akv --resource-group $rgp
}

# Creacion del Container Registry
$acrCheck = az acr list --query "[?name=='$acr']" | ConvertFrom-Json
$acrExists = $acrCheck.Length -gt 0
if (!$acrExists) {
    az acr create --resource-group $rgp --name $acr --sku Basic
}

# Creacion del ServicePrincipal
$acrCheck = az acr list --query "[?name=='$acr']" | ConvertFrom-Json

$spCheck = az ad sp list --query "[?displayName=='$asp']" | ConvertFrom-Json
$spExists = $spCheck.Length -gt 0
if (!$spExists) {
    $spResp = $(az ad sp create-for-rbac -n $asp --role AcrPull --scopes $acrCheck.id | ConvertFrom-Json )
    $spResp
    az keyvault secret set --vault-name $akv --name $asp'appId' --value $spResp.appId
    az keyvault secret set --vault-name $akv --name $asp'password' --value $spResp.password
}

# Creacion del Kubernetes Service
$aksCheck = az aks list --query "[?name=='$aks']" | ConvertFrom-Json
$aksExists = $aksCheck.Length -gt 0
if (!$aksExists) {
    $spId = $(az keyvault secret show --vault-name $akv --name $asp'appId' | ConvertFrom-Json).value
    $spPw = $(az keyvault secret show --vault-name $akv --name $asp'password' | ConvertFrom-Json).value
    az aks create -n $aks -g $rgp --location $loc --node-count 2 --load-balancer-sku basic --service-principal $spId --client-secret $spPw
}
