# Adds custom +where+ functionality to Array class

# Returns true if +key+, +value+ pair was matched (or partially
# matched) within hash.  Returns false if +hash+ is not a +Hash+
def hash_contains(hash, key, value)
  if !hash.is_a?(Hash)
    false
  elsif value.is_a?(Regexp)
    (hash[key] =~ value) != nil
  else
    hash[key] == value
  end
end


class Array
  # Returns an array of values that match (or partially match) the
  # passed +attributes+
  # Params:
  # +attributes+:: +Hash+ Key, values that must match (or partially
  #                match) elements
  def where(attributes)
    find_all { |element|
      attributes.all? { |key, value|
        hash_contains(element, key, value)
      }
    }
  end
end
