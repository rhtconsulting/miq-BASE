# vmware_customizerequest.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method is used to set VMware Customization Specifications and Customization Templates
#
def log_and_update_message(level, msg, update_message = false)
  $evm.log(level, "#{msg}")
  @task.message = msg if @task && (update_message || level == 'error')
end

def set_customspec(spec)
  begin
    @task.set_customization_spec(spec, true)
  rescue
  end
  unless @task.get_option(:sysprep_custom_spec).blank?
    log_and_update_message(:info, "Provisioning object updated {:sysprep_custom_spec => #{@task.options[:sysprep_custom_spec].inspect}}")
    log_and_update_message(:info, "Provisioning object updated {:sysprep_spec_override => #{@task.get_option(:sysprep_spec_override)}}")
  end
end

def process_vmware()
  if @task.get_option(:sysprep_custom_spec).nil?
    if @product.include?("red hat") || @product.include?("suse") || @product.include?("windows")
      if @product.include?("2008")
        spec = "vmware_windows" # Windows Server 2008
      elsif @product.include?("2012")
        spec = "vmware_windows" # Windows 2012
      elsif @product.include?("windows 7")
        spec = "vmware_windows" # Windows7
      elsif @product.include?("suse")
        spec = "vmware_suse" # Suse
      elsif @product.include?("red hat")
        spec = "vmware_rhel" # RHEL
      else
        spec = nil
      end
      set_customspec(spec) unless spec.nil?
      if @task.get_option(:sysprep_custom_spec).nil?
        # try matching customization spec against the template name
        spec = @template.name # to match the template name
        set_customspec(spec) unless spec.nil?
      end
      if @task.get_option(:sysprep_custom_spec).nil?
        log_and_update_message(:warn, "Unable to set a customization_spec")
      end
    else
      log_and_update_message(:info, "Invalid product detected: #{@product}")
    end
  else
    log_and_update_message(:info, "Customization Specification already chosen via dialog: #{@task.options[:sysprep_custom_spec]}")
  end
end

def process_vmware_pxe()
  if @product.include?("windows")
    # find the first windows image that matches the template name if a PXE Image was NOT chosen in the dialog
    if @task.get_option(:pxe_image_id).nil?
      log_and_update_message(:info, "Inspecting Eligible Windows Images: #{@task.eligible_windows_images.inspect rescue nil}")
      pxe_image = @task.eligible_windows_images.detect { |pi| pi.name.casecmp(@template.name) == 0 }
      if pxe_image.nil?
        log_and_update_message(:warn, "Unable to find matching Windows Image", true)
      else
        log_and_update_message(:info, "Found matching Windows PXE Image ID: #{pxe_image.id} Name: #{pxe_image.name} Description: #{pxe_image.description}")
        @task.set_windows_image(pxe_image)
        log_and_update_message(:info, "Provisioning object updated {:pxe_image_id => #{@task.options[:pxe_image_id].inspect}}")
      end
    end
    # Find the first customization template that matches the template name if none was chosen in the dialog
    if @task.get_option(:customization_template_id).nil?
      log_and_update_message(:info, "Inspecting Eligible Customization Templates: #{@task.eligible_customization_templates.inspect rescue nil}")
      cust_temp = @task.eligible_customization_templates.detect { |ct| ct.name.casecmp(@template.name) == 0 }
      if cust_temp.nil?
        log_and_update_message(:warn, "Unable to find matching customization template", true)
      else
        log_and_update_message(:info, "Found mathcing Windows Customization Template ID: #{cust_temp.id} Name: #{cust_temp.name} Description: #{cust_temp.description}")
        @task.set_customization_template(cust_temp)
        log_and_update_message(:info, "Provisioning object updated {:customization_template_id => #{@task.options[:customization_template_id].inspect}}")
      end
    end
  else
    # find the first PXE Image that matches the template name if NOT chosen in the dialog
    if @task.get_option(:pxe_image_id).nil?
      pxe_image = @task.eligible_pxe_images.detect { |pi| pi.name.casecmp(@template.name) == 0 }
      if pxe_image.nil?
        log_and_update_message(:warn, "Unable to find matching PXE Image", true)
      else
        log_and_update_message(:info, "Found Linux PXE Image ID: #{pxe_image.id}  Name: #{pxe_image.name} Description: #{pxe_image.description}")
        @task.set_pxe_image(pxe_image)
        log_and_update_message(:info, "Provisioning object updated {:pxe_image_id => #{@task.options[:pxe_image_id].inspect}}")
      end
    end
    # Find the first Customization Template that matches the template name if NOT chosen in the dialog
    if @task.get_option(:customization_template_id).nil?
      log_and_update_message(:info, "Inspecting Eligible Customization Templates: #{@task.eligible_customization_templates.inspect rescue nil}")
      cust_temp = @task.eligible_customization_templates.detect { |ct| ct.name.casecmp(@template.name) == 0 }
      if cust_temp.nil?
        log_and_update_message(:warn, "Unable to find matching customization template", true)
      else
        log_and_update_message(:info, "Found Customization Template ID: #{cust_temp.id} Name: #{cust_temp.name} Description: #{cust_temp.description}")
        @task.set_customization_template(cust_temp)
        log_and_update_message(:info, "Provisioning object updated {:customization_template_id => #{@task.get_option(:customization_template_id).inspect}}")
      end
    end
  end
end

begin
  # Get provisioning object
  @task = $evm.root["miq_provision"]

  log_and_update_message(:info, "Provision:<#{@task.id}> Request:<#{@task.miq_provision_request.id}> Type:<#{@task.type}>")

  @template = @task.vm_template
  @provider = @template.ext_management_system
  @product  = @template.operating_system['product_name'].downcase rescue nil
  log_and_update_message(:info, "Template: #{@template.name} Provider: #{@provider.name} Vendor: #{@template.vendor} Product: #{@product}")

  # Build case statement to determine which type of processing is required
  case @task.type
  when 'MiqProvisionVmware'
    # VMware Customization Specification
    process_vmware()
  when 'MiqProvisionVmwareViaPxe'
    # VMware PXE Customization Template
    process_vmware_pxe()
  else
    log_and_update_message(:info, "Provisioning Type: #{@task.type} does not match, skipping processing")
  end

  # Set linux hostname stuff here for customization spec handling
  @task.set_option(:linux_host_name, @task.get_option(:vm_target_name))
  log_and_update_message(:info, "Provisioning object updated {:linux_host_name => #{@task.get_option(:linux_host_name)}}")
  @task.set_option(:host_name, @task.get_option(:vm_target_name))
  log_and_update_message(:info, "Provisioning object updated {:host_name => #{@task.get_option(:host_name)}}")
  @task.set_option(:vm_target_hostname, @task.get_option(:vm_target_name))
  log_and_update_message(:info, "Provisioning object updated {:vm_target_hostname => #{@task.get_option(:vm_target_hostname)}}")

  # Log all of the provisioning options to the automation.log
  @task.options.each { |k,v| log_and_update_message(:info, "Provisioning Option Key: #{k.inspect} Value: #{v.inspect}") }

  # Set Ruby rescue behavior
rescue => err
  log_and_update_message(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
