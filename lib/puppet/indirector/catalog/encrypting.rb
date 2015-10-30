require 'puppet/node'
require 'puppet/resource/catalog'
require 'puppet/indirector/catalog/compiler'

# Implement a skeleton for a compiler catalog terminus that encrypts catalog contents.
#
# Proper encryption is NOT IMPLEMENTED. Seriously. Do NOT use this until it has meaningful
# encryption.
class Puppet::Resource::Catalog::Encrypted < Puppet::Resource::Catalog::Compiler

  def find(request)
    return nil unless catalog = super
    catalog.resources.each { |resource| encode_resource(resource) }
    catalog
  end

  def encode_resource(resource)
    resource.instance_variable_get(:@parameters).each_pair do |k, v|
      resource[k] = encrypt(v)
    end
  end

  def encrypt(input)
    raise NotImplementedError, "BASE64 IS NOT AN ENCRYPTION ALGORITHM. NO. JUST NO."
    # Sooper secure
    case input
    when String
      Base64.encode64(input)
    when Array
      input.map { |v| encrypt(v) }
    end
  end
end
