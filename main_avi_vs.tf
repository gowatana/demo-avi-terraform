provider "avi" {
  avi_controller = "vcf-m01-avi.c.go-lab.jp"
  avi_tenant     = "admin"
  avi_username   = "admin"
  avi_password   = var.avi_password
  avi_version    = "22.1.7"
}

variable "avi_password" {
  description = "AVI Controller password"
  type        = string
  sensitive   = true
}

data "avi_applicationprofile" "system_http_profile" {
  name = "System-HTTP"
}

data "avi_healthmonitor" "monitor" {
  name = "System-HTTP"
}

data "avi_cloud" "nsx_cloud" {
  name = "VCF-NSX-Cloud"
}

data "avi_vrfcontext" "vrfcontext" {
  name      = "vcf-m01-t1"
  cloud_ref = data.avi_cloud.nsx_cloud.id
}

data "avi_network" "vip_network" {
  name      = "seg-overlay-avi-data"
  cloud_ref = data.avi_cloud.nsx_cloud.id
}

data "avi_serviceenginegroup" "vcf_segroup" {
  name      = "VCF-Avi-SE-Group"
  cloud_ref = data.avi_cloud.nsx_cloud.id
}

resource "avi_pool" "web_pool" {
  name         = "Web-Pool-02"
  lb_algorithm = "LB_ALGORITHM_ROUND_ROBIN"
  analytics_policy {
    enable_realtime_metrics = "true"
  }
  servers {
    ip {
      type = "V4"
      addr = "10.0.1.11"
    }
    port = 80
  }
  servers {
    ip {
      type = "V4"
      addr = "10.0.1.12"
    }
    port = 80
  }
  health_monitor_refs = [data.avi_healthmonitor.monitor.id]
  cloud_ref           = data.avi_cloud.nsx_cloud.id
  vrf_ref             = data.avi_vrfcontext.vrfcontext.id
}

resource "avi_vsvip" "vip" {
  name = "Web-VIP-02"
  vip {
    vip_id = "0"

    #auto_allocate_ip = false
    #ip_address {
    #  type = "V4"
    #  addr = "10.0.11.210"
    #}

    auto_allocate_ip      = true
    auto_allocate_ip_type = "V4_ONLY"
    ipam_network_subnet {
      network_ref = data.avi_network.vip_network.id
      subnet {
        ip_addr {
          addr = "10.0.11.0"
          type = "V4"
        }
        mask = "24"
      }
    }
  }
  cloud_ref       = data.avi_cloud.nsx_cloud.id
  vrf_context_ref = data.avi_vrfcontext.vrfcontext.id
}

resource "avi_virtualservice" "http_vs" {
  name       = "Web-VS-02"
  cloud_type = "CLOUD_NSXT"
  services {
    port           = 80
    port_range_end = 80
    enable_ssl     = false
  }
  analytics_policy {
    metrics_realtime_update {
      enabled  = true
      duration = 0
    }
    all_headers = false
    full_client_logs {
      enabled  = true
      duration = 0
    }
  }
  cloud_ref               = data.avi_cloud.nsx_cloud.id
  vrf_context_ref         = data.avi_vrfcontext.vrfcontext.id
  vsvip_ref               = avi_vsvip.vip.id
  application_profile_ref = data.avi_applicationprofile.system_http_profile.id
  pool_ref                = avi_pool.web_pool.id
  se_group_ref            = data.avi_serviceenginegroup.vcf_segroup.id
  scaleout_ecmp           = false
  lifecycle {
    ignore_changes = [scaleout_ecmp]
  }
}

output "vip_address" {
  value = [for vip in avi_vsvip.vip.vip : one(vip.ip_address).addr][0]
}

