terraform {
  required_providers {
    avi = {
      source  = "vmware/avi"
      version = "22.1.7"
    }
  }

  cloud { 
    organization = "go-lab" 
    workspaces { 
      name = "vcf-avi" 
    } 
  } 
}

