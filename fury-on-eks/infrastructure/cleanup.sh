#!/bin/bash
GREEN='\033[0;32m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'

# Clear the color after that
CLEAR='\033[0m'
TAG_KEY="kubernetes.io/cluster/fury-eks-demo"
TAG_VALUE="owned"

echo -e "$BLUE------------------------$CLEAR"
echo -e "$GREEN RUNNING CLEANUP SCRIPT!$CLEAR"
echo -e "$BLUE------------------------$CLEAR"
echo -e ""

echo -e "$GREEN ---- LOADBALANCERS ----$CLEAR"
loadbalancer=$(aws resourcegroupstaggingapi get-resources  \
               --tag-filters Key=$TAG_KEY,Values=$TAG_VALUE | jq -r ".ResourceTagMappingList[] | .ResourceARN" | grep loadbalancer)
for i in $loadbalancer; 
do 
  echo -e "$BLUE Deleting Loadbalancer -->$CLEAR $MAGENTA[ $i ]$CLEAR";
   aws elbv2 delete-load-balancer --load-balancer-arn $i ; 
done

echo -e ""

echo -e "$GREEN ---- TARGET GROUPS ----$CLEAR"
target_groups=$(aws resourcegroupstaggingapi get-resources \
                --tag-filters Key=$TAG_KEY,Values=$TAG_VALUE  | jq -r ".ResourceTagMappingList[] | .ResourceARN" | grep targetgroup)
for i in $target_groups; 
do 
  echo -e "$BLUE Deleting Target group -->$CLEAR $MAGENTA[ $i ]$CLEAR";
   aws elbv2 delete-target-group --target-group-arn $i ; 
done

echo -e ""

echo -e "$GREEN ---- SNAPSHOTS ----$CLEAR"
snapshots=$(aws ec2 describe-snapshots --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" \
            --query "Snapshots[*].[SnapshotId]" --output text)
for i in $snapshots; 
do 
  echo -e "$BLUE Deleting Snapshot -->$CLEAR $MAGENTA[ $i ]$CLEAR";
  aws ec2 delete-snapshot --snapshot-id $i ; 
done

echo -e ""

echo -e "$GREEN ---- VOLUMES ----$CLEAR"
volumes=$(aws ec2 describe-volumes --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" \
            --query "Volumes[*].[VolumeId]" --output text)
for i in $volumes; 
do 
  echo -e "$BLUE Deleting volume -->$CLEAR $MAGENTA[ $i ]$CLEAR";
  aws ec2 delete-volume --volume-id $i ; 
done
echo -e ""
echo -e "$MAGENTA------------------------$CLEAR"
echo -e "$GREEN CLEANUP SCRIPT DONE!$CLEAR"
echo -e "$MAGENTA------------------------$CLEAR"