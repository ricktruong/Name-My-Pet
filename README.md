# Name-My-Pet
Run my fun and simple OpenAI App which gives 3 pet superhero names for any pet animal you'd like!

https://github.com/ricktruong/Name-My-Pet/assets/19510820/b2a3b103-12ae-415b-b7bc-7db0f6335982


## Accreditation
This project's main application code was taken directly from [OpenAI's API Quickstart Tutorial](https://platform.openai.com/docs/quickstart). This project's Terraform configuration files were largely based on a [tutorial put out by Hashicorp](https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks). Lastly, the development of this project was made possible by Vinod Kisanagaram's tutorial on Medium, [Python App on EKS — From Scratch to Hosting](https://towardsaws.com/python-app-on-eks-from-scratch-to-hosting-af040f8dacf0), and the [Amazon EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html).

## Setup
### Prerequisites
In order to provision the infrastructure needed to launch my project, the following are needed:

- Terraform v1.3+ installed locally.
- an AWS account
- the AWS CLI v2.7.0/v1.24.0 or newer, installed and configured
- AWS IAM Authenticator
- kubectl v1.24.0 or newer

### Tutorial
#### Clone Source Code
In Terminal, clone this repository with the below command:
```bash
$ git clone https://github.com/ricktruong/Name-My-Pet.git
```

Change into the repository directory
```bash
$ cd Name-My-Pet
```

#### Gain Access to AWS resources
Export the credentials for your AWS Account with the appropriate permissions into terminal to gain programmatic access to accessing and creating AWS resources, including Amazon EKS resources
```bash
$ export AWS_ACCESS_KEY_ID=$YOUR_AWS_ACCESS_KEY_ID
$ export AWS_SECRET_ACCESS_KEY=$YOUR_AWS_SECRET_ACCESS_KEY
$ export AWS_SESSION_TOKEN=$YOUR_AWS_SESSION_TOKEN
```

#### Initialize Terraform Workspace
Change into the Terraform directory of the project
```bash
$ cd ./Terraform
```

Initialize this directory's configuration
```bash
$ terraform init
```

#### Provision the EKS Cluster
Provision your EKS cluster and other necessary resources through running <code>terraform apply</code>. Confirm the operation with a <code>yes</code>.

This process can take up to 20 minutes. Upon completion, Terraform will print your configuration's outputs.

```bash
$ terraform apply

# ...

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create
 <= read (data resources)

Terraform will perform the following actions:

# ...

Plan: 63 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + cluster_endpoint          = (known after apply)
  + cluster_name              = (known after apply)
  + cluster_security_group_id = (known after apply)
  + region                    = "us-east-2"

Do you want to perform these actions in workspace "learn-terraform-eks"?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

# ...

Apply complete! Resources: 63 added, 0 changed, 0 destroyed.

Outputs:

cluster_endpoint = "https://128CA2A0D737317D36E31D0D3A0C366B.gr7.us-east-2.eks.amazonaws.com"
cluster_name = "education-eks-IKQYD53K"
cluster_security_group_id = "sg-0f836e078948afb70"
region = "us-east-2"
```

#### Configure kubectl
After your cluster has been provisioned, you will need to configure <code>kubectl</code> to communicate with it.

Retrieve the proper access credentials for your cluster to and configure <code>kubectl</code> by running the following:
```bash
$ aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)
```

Verify that <code>kubectl</code> is configured properly to your cluster.
```bash
$ kubectl cluster-info
Kubernetes control plane is running at https://128CA2A0D737317D36E31D0D3A0C366B.gr7.us-east-2.eks.amazonaws.com
CoreDNS is running at https://128CA2A0D737317D36E31D0D3A0C366B.gr7.us-east-2.eks.amazonaws.com/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```
Ensure that the Kubernetes control plane location matches the <code>cluster_endpoint</code> value from the previous <code>terraform apply</code> output above.

#### Deploy application software to cluster
Now that <code>kubectl</code> is properly connected to our EKS cluster, we can begin deploying our application software to the nodes in our cluster.

Run the following command to create a Kubenetes deployment:
```bash
$ kubectl apply -f ../kube/deployments/deployment.yaml
```

Check
```bash
$ kubectl get deployments
NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
name-my-pet-deployment   1/1     1            1           4s
```

Check to see the value under <code>READY</code> is <code>1/1</code>. This means that the newly created <code>name-my-pet-deployment</code> has finished installing the application software on the sole node in this deployment. 

If the value under <code>READY</code> is <code>0/1</code>, wait until the value turns to <code>1/1</code> before moving onto the next step. If the value does not change to <code>1/1</code> after a few minutes, check to see if you've ran the previous steps in the tutorial correctly.

#### Expose the cluster publicly to the Internet
After verifying that our application software has been deployed on our cluster, we will need to expose our cluster to the internet so that we can access Name My Pet online.

Run the following to expose our cluster publicly:
```bash
$ kubectl apply -f ../kube/services/clusterip-service.yaml -f ../kube/services/nodeport-service.yaml
```

Check
```bash
$ kubectl get svc
NAME                            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
kubernetes                      ClusterIP   172.20.0.1       <none>        443/TCP          20m
name-my-pet-clusterip-service   ClusterIP   172.20.141.200   <none>        5000/TCP         61s
name-my-pet-nodeport-service    NodePort    172.20.58.196    <none>        5000:31479/TCP   60s
```

Check to see if <code>name-my-pet-clusterip-service</code> and <code>name-my-pet-nodeport-service</code> have been created.

#### Accessing Name My Pet
After provisioning our EKS infrastructure along with its necessary components, deployed Name My Pet's application software onto our cluster nodes, and exposed our cluster nodes to the internet, it's time to access Name My Pet!

In order to access Name My Pet, we will need to determine the external IP address of our EKS cluster node that is running our application software. Run the subsequent command:
```bash
$ kubectl get nodes -o wide
```

Here, you should receive an output which looks similar to the following:
```bash
NAME                                       STATUS   ROLES    AGE    VERSION               INTERNAL-IP   EXTERNAL-IP   OS-IMAGE         KERNEL-VERSION                  CONTAINER-RUNTIME
ip-10-0-4-206.us-east-2.compute.internal   Ready    <none>   179m   v1.27.3-eks-a5565ad   10.0.4.206    3.14.253.23   Amazon Linux 2   5.10.184-175.731.amzn2.x86_64   containerd://1.6.19
```

Under <code>EXTERNAL-IP</code> lies the external IP address of our cluster node which is running Name My Pet.

Pair the external IP address for the node with port number <code>31479</code> in the following way and paste into your browser url:
```
http://EXTERNAL-IP:31479
So for my case, I would put in http://3.14.253.23:31479 into my web browser.
```

and viola! 

You've finally accessed Name My Pet Online.

## Contact
If you liked my simple Name My Pet project, feel free to follow me at my [LinkedIn](https://www.linkedin.com/in/rick-truong/)! 
If anyone has any questions, comments, or concerns, don't hesitate to message me at rickvtruong@gmail.com.
Add me on [Facebook](https://www.facebook.com/rick.truong.5) and [Instagram](https://www.instagram.com/ricktruong) as well :)