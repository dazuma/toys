# Copyright 2018 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
;

##
# Base module for tool classes
#
module ToysToolClasses
  ##
  # Add the given tool class to the class hierarchy.
  #
  def self.add(tool_class, words, priority, loader)
    if words.empty?
      mangled_name =
        if priority > 0
          "TOYSroot_Pp#{priority}"
        elsif priority < 0
          "TOYSroot_Pm#{-priority}"
        else
          "TOYSroot_P0"
        end
      parent_class = base_module(loader)
    else
      parent_class = loader.get_tool_class(words.slice(0..-2), priority)
      mangled_name = "TOYStool_" + words.last.gsub("_", "_u_").gsub("-", "_h_")
    end
    parent_class.const_set(mangled_name, tool_class)
  end

  ##
  # Return a base module unique to the given object.
  #
  def self.base_module(loader)
    base_name = "TOYSbase_#{loader.object_id}"
    return const_get(base_name) if const_defined?(base_name)
    mod = ::Module.new
    const_set(base_name, mod)
    mod
  end
end
