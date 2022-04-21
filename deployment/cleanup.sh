# Update service desired count to 0
aws ecs update-service --cluster "dash-ecs-cluster" --service "dash-app-1-service" --desired-count 0 --output text

sleep 30

# Fetch all the definition revisions for dash-app-1
dashApp1TaskDefnArns=`aws ecs list-task-definitions --family-prefix dash-app-1 --query taskDefinitionArns[] --output text`

# Deregister each task definition
for dashApp1TaskDefnArn in $dashApp1TaskDefnArns
do
    aws ecs deregister-task-definition --task-definition $dashApp1TaskDefnArn --output text
    echo "$dashApp1TaskDefnArn dregsitered"
done

# Fetch all the definition revisions for dash-app-1
dashApp2TaskDefnArns=`aws ecs list-task-definitions --family-prefix dash-app-2 --query taskDefinitionArns[] --output text`

# Deregister each task definition
for dashApp2TaskDefnArn in $dashApp2TaskDefnArns
do
    aws ecs deregister-task-definition --task-definition $dashApp2TaskDefnArn --output text
    echo "$dashApp2TaskDefnArn dregsitered"
done

# Delete Service
aws ecs delete-service --cluster "dash-ecs-cluster" --service "dash-app-1-service" --output text

# Get dash load balancer arn
loadBalancerArn=`aws elbv2 describe-load-balancers --names dash-load-balancer --query LoadBalancers[0].LoadBalancerArn --output text`

# Get target groups for load balancer
targetGroupArns=`aws elbv2 describe-target-groups --load-balancer-arn $loadBalancerArn --query TargetGroups[].TargetGroupArn --output text`

# Delete load balancer
aws elbv2 delete-load-balancer --load-balancer-arn $loadBalancerArn
echo "Load balancer deleted $loadBalancerArn"

# for each target group arn, delete
for targetGroupArn in $targetGroupArns
do
    aws elbv2 delete-target-group --target-group-arn $targetGroupArn
    echo "$targetGroupArn target group deleted"
done

# Delete ECS cluster
aws ecs delete-cluster --cluster "dash-ecs-cluster" --output text
echo "Cluster dash-ecs-cluster deleted"

###################################################################################

# Get vpc by name tag
vpcId=`aws ec2 describe-vpcs --filters "Name=tag:Name,Values=dash-vpc" --query Vpcs[0].VpcId --output text`

# Get public route table
publicRouteTableAssociations=`aws ec2 describe-route-tables --filters "Name=tag:Name,Values=dash-public-route-table" --query RouteTables[].Associations[].RouteTableAssociationId --output text`

# Get public route table Id
publicRouteTableId=`aws ec2 describe-route-tables --filters "Name=tag:Name,Values=dash-public-route-table" --query RouteTables[].Associations[0].RouteTableId --output text`

# for each route table association, disassociate
for publicRouteTableAssociation in $publicRouteTableAssociations
do
    aws ec2 disassociate-route-table --association-id $publicRouteTableAssociation
    echo "$publicRouteTableAssociation disassociated from public subnet"
done

# Delete public route table
aws ec2 delete-route-table --route-table-id $publicRouteTableId
echo "Public route table deleted $publicRouteTableId"

# Get private route table
privateRouteTableAssociations=`aws ec2 describe-route-tables --filters "Name=tag:Name,Values=dash-private-route-table" --query RouteTables[].Associations[].RouteTableAssociationId --output text`

# Get private route table Id
privateRouteTableId=`aws ec2 describe-route-tables --filters "Name=tag:Name,Values=dash-private-route-table" --query RouteTables[].Associations[0].RouteTableId --output text`

# for each route table association, disassociate
for privateRouteTableAssociation in $privateRouteTableAssociations
do
    aws ec2 disassociate-route-table --association-id $privateRouteTableAssociation
    echo "$privateRouteTableAssociation disassociated from private subnet"
done

# Delete private route table
aws ec2 delete-route-table --route-table-id $privateRouteTableId
echo "Private route table deleted $privateRouteTableId"

# Get internet gateways for the vpc found above
igId=`aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$vpcId --query InternetGateways[].InternetGatewayId --output text`

# Detach internet gateway
aws ec2 detach-internet-gateway --internet-gateway-id $igId --vpc-id $vpcId
echo "$igId detached from $vpcId"

# Delete internet gateway
aws ec2 delete-internet-gateway --internet-gateway-id $igId
echo "$igId deleted"

# Get all security groups for the vpc found above
sgIds=`aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpcId" --query SecurityGroups[].GroupId --output text`

# Delete security group
for sgId in $sgIds
do
    aws ec2 delete-security-group --group-id $sgId --output text
echo "security group deleted"
done

# Get all nat gateways
natGetewayId=`aws ec2 describe-nat-gateways --query NatGateways[0].NatGatewayId --output text`

# Delete nat gateway
aws ec2 delete-nat-gateway --nat-gateway-id $natGetewayId --output text
echo "Nat gatway deleted $natGetewayId"

sleep 150

# Get all elastic ips
elasticAllocationId=`aws ec2 describe-addresses --query Addresses[0].AllocationId --output text`

# Release elastic public ip
aws ec2 release-address --allocation-id $elasticAllocationId
echo "Elastic ip $elasticAllocationId released"

# Get all subnets for the vpc found above
subnetIds=`aws ec2 describe-subnets --filters Name=vpc-id,Values=$vpcId --query Subnets[].SubnetId --output text`

# Delete subnet for each id
for subnetId in $subnetIds
do
    aws ec2 delete-subnet --subnet-id $subnetId
    echo "$subnetId subnet deleted"
done

# Delete the Vpc
aws ec2 delete-vpc --vpc-id $vpcId
echo "$vpcId VPC deleted"
