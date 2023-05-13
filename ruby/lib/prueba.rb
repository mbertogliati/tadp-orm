require 'tadb'

class ObjectNotFound < Exception
  attr_accessor :objeto

  def initialize(objeto)
    self.objeto = objeto
  end
end

module Persistible
  # punto 1

  attr_accessor :instance_keys

  def initialize()
    self.instance_keys = {}
  end

  def self.included(base)
    base.extend(ClasePersistible)
  end

  def id=(id)
    @id = id
  end

  def cargar_con_hash(hash)
    self.definir_metodo_id
    hash.each do |key, value|
      self.send(key.to_s+"=", value)
    end
    self
  end



  def save!

    # En caso de que ya haya hecho un save previo, sobreescribo el registro en la tabla
    if self.respond_to?(:id)
      self.borrar_tabla
    end

    #puts hash_values
    self.definir_metodo_id
    self.id= self.class.table.insert(self.instance_keys)
  end

  def definir_metodo_id
    self.define_singleton_method("id") do
      if self.respond_to?(:id)
        @id
      else
        raise ObjectNotFound(self)
      end
    end
  end

  def borrar_metodo_id
    self.singleton_class.remove_method("id")
  end

  def refresh!
    object_en_base = self.class.table.entries.find{|obj| obj[:id] == self.id}
    if object_en_base
      update_attributes(object_en_base)
    else
      raise ObjectNotFound.new(self)
    end
  end

  def update_attributes(attributes)
    attributes.each do |key, value|
      setter_method = "#{key}="
      send(setter_method, value) if respond_to?(setter_method)
    end
  end

  def forget!
    self.borrar_tabla
    self.borrar_metodo_id
  end

  # punto 2

  def self.all_instances
    lista_hash = self.table.entries

    lista_hash.map! do |hash|
      instancia = self.new
      instancia.cargar_con_hash(hash)
    end

    lista_hash
  end

  def self.find_by(nombre)
    nombre_metodo = "find_by_#{nombre}"
    # Por si se quiere definir comportamiento específico para algún find_by
    if instance_methods.include?(nombre_metodo.to_sym)
      instances = all_instances
      instances.select { |instance| instance.send(method_name) }
    else
      super
    end
  end

  def method_missing(method_name, *args, &block)
    if method_name.to_s.start_with?('find_by_')
      attribute = method_name.to_s.sub('find_by_', '')
      define_find_by_method(attribute)
      send(method_name, *args, &block)
    else
      super
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    method_name.to_s.start_with?('find_by_') || super
  end

  def define_find_by_method(attribute)
    define_singleton_method(attribute) do |value|
      all_instances.select { |instance| instance.send(attribute) == value }
    end
  end

  private
  def borrar_tabla
    self.class.table.delete(@id)
  end

  private :id=

end

module ClasePersistible
  @class_keys = {}
  attr_accessor :class_keys

  def initialize
    self.class_keys = {}
  end

  def table
    @table.nil? ? @table = TADB::DB.table(self.to_s) : @table
  end

  def has_one(tipo, descripcion)

    nombre_atributo = descripcion[:named]

    self.define_method(nombre_atributo) do
      self.instance_keys[nombre_atributo]
    end

    self.define_method(nombre_atributo.to_s+"=") do |valor|
      self.instance_keys[nombre_atributo].valor = valor
    end

    class_keys[nombre_atributo] = tipo
  end

  def all_instances
    lista_hash = self.table.entries

    lista_hash.map! do |hash|
      instancia = self.new
      instancia.cargar_con_hash(hash)
    end

    lista_hash
  end

end

# class AtributoPersistible
#   attr_accessor :tipo, :valor
#   def initialize(tipo, valor)
#     @tipo = tipo
#     @valor = valor
#   end
#
#   def valor= (valor)
#     @valor = valor
#   end
#
# end

module Boolean

end

class Person

  include Persistible

  has_one String, named: :first_name
  has_one String, named: :last_name
  has_one Numeric, named: :age
  has_one Boolean, named: :admin

end



class Main
end