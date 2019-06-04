require "json"
require "topological_inventory/sync/worker"

module TopologicalInventory
  class Sync
    module InventoryUpload
      class ValidatorWorker < Worker
        include Logging

        def queue_name
          "platform.upload.topological-inventory"
        end

        def persist_ref
          "topological-inventory-upload-validator"
        end

        def perform(message)
          payload = JSON.parse(message.payload)

          logger.info("#{payload}")

          inventory = parse_inventory_payload(payload["url"])
          payload["validation"] = valid_payload?(inventory) ? "success" : "failure"

          publish_validation(payload)
        end

        private

        def valid_payload?(payload)
          require "topological_inventory/schema"

          schema_klass = schema_klass_name(payload.dig("schema", "name")).safe_constantize
          schema_klass.present?
        end

        def schema_klass_name(name)
          "TopologicalInventory::Schema::#{name}"
        end

        def open_url(url)
          require "http"

          uri = URI(url)
          if uri.scheme.nil?
            File.open(url) { |f| yield f }
          else
            response = HTTP.get(uri)
            response.body.stream!
            yield response.body
          end
        end

        def untargz(io)
          require "rubygems/package"
          Zlib::GzipReader.wrap(io) do |gz|
            Gem::Package::TarReader.new(gz) do |tar|
              tar.each { |entry| yield entry }
            end
          end
        end

        def parse_inventory_payload(url)
          open_url(url) do |io|
            untargz(io) do |file|
              require "json/stream"
              inventory = JSON::Stream::Parser.parse(file)
            end
          end
        end

        def publish_validation(payload)
          messaging_client.publish_topic(
            :service => "platform.upload.validation",
            :event   => "", # TODO we shouldn't require this in MIQ-Messaging
            :payload => payload.to_json
          )
        end
      end
    end
  end
end
