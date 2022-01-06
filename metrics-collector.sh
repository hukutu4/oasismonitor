#!/bin/bash
#set -x # uncomment to enable debug

#####    Packages required: jq, bc
#####    Oasis Validator Monitoring Script v.0.01 to be used with Telegraf / Grafana / InfluxDB
#####    Fetching data from Oasis validators, outputs metrics in Influx Line Protocol on stdout
#####    Created: 10 Aug 20:39 UTC 2021 by @rustem_a
#####    CONFIG    ##################################################################################################
configDir="/node/etc"  # the directory for the config files, eg.: /node/etc
sockAddr="unix:/node/data/internal.sock"
binDir="/node/bin"
##### optional:
initialSelfStake=600
entityPubkeyRaw=""
identityNodeRaw=""
format="ROSE"
now=$(date +%s%N)
#####  END CONFIG  ##################################################################################################

cli="${binDir}/oasis-node"
oasisControlStatus=$($cli control status -a $sockAddr)

if [ -z $entityPubkeyRaw ]; then entityPubkeyRaw=$(jq -r .registration.descriptor.entity_id <<< $oasisControlStatus); fi
entityPubkey=$(sed -r 's/=/\\=/g' <<< $entityPubkeyRaw)
if [ -z $identityNodeRaw ]; then identityNodeRaw=$(jq -r .identity.node <<< $oasisControlStatus); fi
identityNode=$(sed -r 's/=/\\=/g' <<< $identityNodeRaw)

rosePrice=$(curl -s 'https://api.binance.com/api/v3/ticker/price?symbol=ROSEUSDT' | jq -r .price)

softwareVersion=$(jq -r .software_version <<< $oasisControlStatus)

isValidator=$(jq -r '.consensus.is_validator' <<< $oasisControlStatus)
if [[ $isValidator == true ]]; then isValidatorInt=1; else isValidatorInt=0; fi
peersCount=$(jq -r '.consensus.node_peers | length' <<< $oasisControlStatus)
committeePeersCount=$(jq -r '.runtimes."0000000000000000000000000000000000000000000000000000000000000000".committee.peers | length' <<< $oasisControlStatus)
latestHeight=$(jq -r '.consensus.latest_height' <<< $oasisControlStatus)
latestEpoch=$(jq -r '.consensus.latest_epoch' <<< $oasisControlStatus)

runtimesLatestRound=$(jq -r '.runtimes."0000000000000000000000000000000000000000000000000000000000000000".latest_round' <<< $oasisControlStatus)
if [[ $runtimesLatestRound == null ]]; then runtimesLatestRound=0; fi
runtimesCommitteeLatestHeight=$(jq -r '.runtimes."0000000000000000000000000000000000000000000000000000000000000000".committee.latest_height' <<< $oasisControlStatus)
if [[ $runtimesCommitteeLatestHeight == null ]]; then runtimesCommitteeLatestHeight=0; fi
runtimesExecutorRolesCount=$(jq -r '.runtimes."0000000000000000000000000000000000000000000000000000000000000000".committee.executor_roles | length' <<< $oasisControlStatus)
runtimesStorageRolesCount=$(jq -r '.runtimes."0000000000000000000000000000000000000000000000000000000000000000".committee.storage_roles | length' <<< $oasisControlStatus)
runtimesStorageLastFinalizedRound=$(jq -r '.runtimes."0000000000000000000000000000000000000000000000000000000000000000".storage.last_finalized_round' <<< $oasisControlStatus)
if [[ $runtimesStorageLastFinalizedRound == null ]]; then runtimesStorageLastFinalizedRound=0; fi

registrationLastRegistration=$(jq -r .registration.last_registration <<< $oasisControlStatus | cut -b -19)
registrationExpiration=$(jq -r .registration.descriptor.expiration <<< $oasisControlStatus)
if [[ $registrationExpiration == null ]]; then registrationExpiration=0; fi

logentry="softwareVersion=\"$softwareVersion\""
if [[ -n $rosePrice ]]; then
  logentry="$logentry,rosePrice=$rosePrice"
fi

stakeAccountAddress=$($cli stake pubkey2address --public_key $entityPubkeyRaw)
stakeAccountInfo=$($cli stake account info -a $sockAddr --stake.account.address $stakeAccountAddress)
activeStake=$(grep -A1 'Active Delegations to' <<< $stakeAccountInfo | awk '/Total/ {print $2}')
if [[ -z $activeStake ]]; then activeStake=0; fi
selfStake=$(grep -A1000 'Active Delegations to' <<< $stakeAccountInfo | grep -A1 self | awk '/Amount:/ {print $2}' | head -n1)
if [[ -z $selfStake ]]; then selfStake=0; fi
commissionRate=$(grep -P '^\s+rate' <<< $stakeAccountInfo | tail -n1 | awk '{print $2}' | sed -r 's/%//g')
if [[ -z $commissionRate ]]; then commissionRate=0; fi
currentReward=$(bc <<< "scale=2 ; ($selfStake - $initialSelfStake) * $rosePrice")

logentry="$logentry,peersCount=$peersCount,committeePeersCount=$committeePeersCount,latestHeight=$latestHeight,latestEpoch=$latestEpoch"
logentry="$logentry,runtimesLatestRound=$runtimesLatestRound,runtimesCommitteeLatestHeight=$runtimesCommitteeLatestHeight,runtimesExecutorRolesCount=$runtimesExecutorRolesCount"
logentry="$logentry,runtimesStorageRolesCount=$runtimesStorageRolesCount,runtimesStorageLastFinalizedRound=$runtimesStorageLastFinalizedRound"
logentry="$logentry,registrationLastRegistration=\"$registrationLastRegistration\",registrationExpiration=$registrationExpiration"
logentry="$logentry,isValidator=$isValidator,isValidatorInt=$isValidatorInt,activeStake=$activeStake,selfStake=$selfStake,commissionRate=$commissionRate,currentReward=$currentReward"
logentry="oasismonitor,entity=$entityPubkey,identityNode=$identityNode $logentry $now"
echo $logentry
