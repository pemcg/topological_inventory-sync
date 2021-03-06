require "topological_inventory/sync/inventory_upload/parser"

module TopologicalInventory
  class Sync
    module InventoryUpload
      class Payload
        class Cfme < Payload
          IMPORTED_VALUE = :cfme

          def process
            cfme_ems_types.each do |ems_type|
              payload[ems_type].to_a.each do |provider_payload|
                source_type = ems_type_to_source_type[ems_type]
                source_uid  = provider_payload["guid"]
                source_name = provider_payload["name"]

                logger.info("Processing CFME Provider [#{source_uid}] [#{source_name}]...")

                source = find_or_create_source(:type_name => source_type, :name => source_name, :uid => source_uid, :imported => IMPORTED_VALUE)
                logger.info("Source ID [#{source.id}] Name [#{source.name}] Type [#{source_type}]")

                find_or_create_application(source_type, source)

                if source_exists_in_topology_inventory?(source_uid)
                  inventory = Parser::Cfme.parse(source_type, source_uid, source_name, provider_payload)
                  send_to_ingress_api(inventory)

                  logger.info("Processing CFME Provider [#{source_uid}] [#{source_name}]...Complete")
                end
              end
            end
          end

          private

          def ems_type_to_source_type
            @ems_type_to_source_type ||= {
              "ManageIQ::Providers::Openstack::CloudManager" => "openstack",
              "ManageIQ::Providers::Redhat::InfraManager"    => "ovirt",
              "ManageIQ::Providers::Vmware::InfraManager"    => "vsphere"
            }.freeze
          end

          def cfme_ems_types
            ems_type_to_source_type.keys
          end
        end
      end
    end
  end
end
