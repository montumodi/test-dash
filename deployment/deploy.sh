# Create vpc
vpcId=`aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query Vpc.VpcId --output text`
echo "$vpcId vpc created"

# Add name to the vpc
aws ec2 create-tags --resources $vpcId --tags Key=Name,Value=dash-vpc
echo "$vpcId vpc name added"

# Create Internet gateway
igId=`aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text`
echo "Internet gateway created $igId"

# Attach Internet gateway
aws ec2 attach-internet-gateway --internet-gateway-id $igId --vpc-id $vpcId
echo "Internet gateway $igId attahced to $vpcId"

# Create 2 sets of public subnets and 2 sets of private subnets.
publicSubnet1=`aws ec2 create-subnet --vpc-id $vpcId --cidr-block 10.0.0.0/20 --availability-zone-id euw1-az1 --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=dash-public-subnet-1}]" --query Subnet.SubnetId --output text`
echo "Public subnet 1 created - $publicSubnet1"

publicSubnet2=`aws ec2 create-subnet --vpc-id $vpcId --cidr-block 10.0.16.0/20 --availability-zone-id euw1-az2 --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=dash-public-subnet-2}]" --query Subnet.SubnetId --output text`
echo "Public subnet 2 created - $publicSubnet2"

privateSubnet1=`aws ec2 create-subnet --vpc-id $vpcId --cidr-block 10.0.128.0/20 --availability-zone-id euw1-az1 --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=dash-private-subnet-1}]" --query Subnet.SubnetId --output text`
echo "Private subnet 1 created - $privateSubnet1"

privateSubnet2=`aws ec2 create-subnet --vpc-id $vpcId --cidr-block 10.0.144.0/20 --availability-zone-id euw1-az2 --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=dash-private-subnet-2}]" --query Subnet.SubnetId --output text`
echo "Private subnet 2 created - $privateSubnet2"

# Create public route table
publicRouteTableId=`aws ec2 create-route-table --vpc-id $vpcId --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=dash-public-route-table}]" --query RouteTable.RouteTableId --output text`
echo "Public route table created - $publicRouteTableId"

# Create public route in the public route table created
aws ec2 create-route --route-table-id $publicRouteTableId --destination-cidr-block "0.0.0.0/0" --gateway-id $igId --output text
echo "Public route added to public route table $publicRouteTableId"

# Associate public subnet 1 with public route table
aws ec2 associate-route-table --subnet-id $publicSubnet1 --route-table-id $publicRouteTableId --output text
echo "Public subnet $publicSubnet1 associated with route table $publicRouteTableId"

# Associate public subnet 2 with public route table
aws ec2 associate-route-table --subnet-id $publicSubnet2 --route-table-id $publicRouteTableId --output text
echo "Public subnet $publicSubnet2 associated with route table $publicRouteTableId"

# Create private route table
privateRouteTableId=`aws ec2 create-route-table --vpc-id $vpcId --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=dash-private-route-table}]" --query RouteTable.RouteTableId --output text`
echo "Private route table created - $privateRouteTableId"

# Create elastic ip
allocationId=`aws ec2 allocate-address --query AllocationId --output text`
echo "Elastic ip created $allocationId"

# Create NAT Gateway
natGatewayId=`aws ec2 create-nat-gateway --allocation-id $allocationId --subnet-id $publicSubnet2 --query NatGateway.NatGatewayId --output text`
echo "Nat gateway created $natGatewayId"

sleep 40

# Create private route in the private route table created
aws ec2 create-route --route-table-id $privateRouteTableId --destination-cidr-block "0.0.0.0/0" --nat-gateway-id $natGatewayId --output text
echo "Private route added to private route table $privateRouteTableId"

# Associate private subnet 1 with private route table
aws ec2 associate-route-table --subnet-id $privateSubnet1 --route-table-id $privateRouteTableId --output text
echo "Private subnet $privateSubnet1 associated with route table $privateRouteTableId"

# Associate public subnet 2 with public route table
aws ec2 associate-route-table --subnet-id $privateSubnet2 --route-table-id $privateRouteTableId --output text
echo "Private subnet $privateSubnet2 associated with route table $privateRouteTableId"

###################################################################################

# Create ECS cluster
clusterArn=`aws ecs create-cluster --cluster-name "dash-ecs-cluster" --capacity-providers "FARGATE" --query cluster.clusterArn --output text`
echo "ECS cluster $clusterArn created" 

# Regiter task defintions for both dash images
aws ecs register-task-definition --cli-input-json file:///Users/modia1/Documents/stuff/projects/icis/test-dash/deployment/dash-app-1-task-def.json --output text
aws ecs register-task-definition --cli-input-json file:///Users/modia1/Documents/stuff/projects/icis/test-dash/deployment/dash-app-2-task-def.json --output text

# Create security group
loadBalancerSecurityGroupId=`aws ec2 create-security-group --description "SG to allow access from everywhere on port 80" --group-name "Load-Balancer-SG" --vpc-id $vpcId --output text`
echo "Security group created $loadBalancerSecurityGroupId"

# Add inbound rules in security group
aws ec2 authorize-security-group-ingress --group-id $loadBalancerSecurityGroupId --port 80 --protocol tcp --cidr "0.0.0.0/0" --output text

# Create security group
dashSecurityGroupId=`aws ec2 create-security-group --description "SG to allow access from everywhere on port 8050" --group-name "Dash-SG" --vpc-id $vpcId --output text`
echo "Security group created $dashSecurityGroupId"

# Add inbound rules in security group
aws ec2 authorize-security-group-ingress --group-id $dashSecurityGroupId --port 8050 --protocol tcp --source-group $loadBalancerSecurityGroupId --output text

# Create target group for dash app 1
dashApp1TargetGroupArn=`aws elbv2 create-target-group --name dash-app-1-tg --target-type ip \
    --protocol HTTP \
    --port 8050 \
    --vpc-id $vpcId \
    --health-check-path "/apps/dash-app-1/" \
    --query TargetGroups[0].TargetGroupArn \
    --output text`

# Create Application load balancer
loadBalancerArn=`aws elbv2 create-load-balancer --name dash-load-balancer \
    --subnets $publicSubnet1 $publicSubnet2 \
    --scheme internet-facing \
    --security-groups $loadBalancerSecurityGroupId \
    --type application \
    --query LoadBalancers[0].LoadBalancerArn \
    --output text`

# Add default listener rule
defaultListenerArn=`aws elbv2 create-listener --load-balancer-arn $loadBalancerArn \
    --protocol HTTP \
    --port 80 \
    --default-actions "Type=fixed-response,FixedResponseConfig={MessageBody=This path doesnt exists,StatusCode=503}" \
    --query Listeners[0].ListenerArn \
    --output text`

# Add rule for dash app 1 to listener
aws elbv2 create-rule --listener-arn $defaultListenerArn \
    --conditions file:///Users/modia1/Documents/stuff/projects/icis/test-dash/deployment/dash-app-1-tg-rule.json \
    --actions Type=forward,TargetGroupArn=$dashApp1TargetGroupArn \
    --priority 1 \
    --output text

# Create service
aws ecs create-service \
    --cluster dash-ecs-cluster \
    --service-name dash-app-1-service \
    --task-definition dash-app-1 \
    --desired-count 1 \
    --launch-type FARGATE \
    --platform-version LATEST \
    --load-balancers "targetGroupArn=$dashApp1TargetGroupArn,containerName=dash-app-1,containerPort=8050" \
    --network-configuration "awsvpcConfiguration={subnets=[$privateSubnet1,$privateSubnet2],securityGroups=[$dashSecurityGroupId],assignPublicIp=DISABLED}" --output text