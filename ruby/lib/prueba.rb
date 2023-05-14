require 'tadb'

class PersistibleNoGuardado < Exception
  attr_accessor :objeto


  def initialize(objeto)
    self.objeto = objeto
  end
end

module Persistible
  # punto 1

  module ClassMethods
    def all_instances
      lista_hash = self.all_entries

      lista_hash.map! do |hash|
        instancia = self.new
        instancia.llenar(hash)
      end
    end

    def find_by(atributo_sym,valor)
      self.all_instances.select { |instancia| instancia.send(atributo_sym) == valor }
    end

    def responds_to_find_by?(nombre_metodo)
      nombre_metodo.start_with?('find_by_') && self.instance_method(nombre_metodo.sub('find_by_', '').to_sym).arity == 0
    end

    def method_missing(sym, *args, &block)
      if responds_to_find_by?(sym.to_s)
        nombre_metodo = sym.to_s.sub('find_by_', '').to_sym
        self.find_by(nombre_metodo, args[0])
      else
        super
      end
    end

    def respond_to_missing?(nombre_metodo, include_private = false)
      responds_to_find_by?(nombre_metodo) || super
    end

  end

  attr_accessor :atributos_persistibles

  def self.included(base)
    base.extend(ClaseDePersistible)
    base.extend(ClassMethods)
  end

  def initialize
    self.atributos_persistibles = {}
  end

  def id
    self.atributos_persistibles[:id]
  end

  def save!
    # En caso de que ya haya hecho un save previo, sobreescribo el registro en la tabla
    if self.respond_to?(:id)
      self.borrar_entrada
    end

    #puts hash_values
    self.atributos_persistibles[:id] = self.class.table.insert(self.atributos_persistibles)
  end

  def refresh!
    raise PersistibleNoGuardado.new(self) if self.id.nil?
    self.atributos_persistibles = self.class.find_entries_by(:id, self.id).first
    self
  end

  def forget!
    self.borrar_entrada
    self.atributos_persistibles[:id] = nil
  end

  def to_object(key,value)
    hash_tipo = self.class.diccionario_de_tipos
    if hash_tipo[key].is_a? Persistible
      hash_tipo[key].find_by_id(value).first
    else
      value
    end
  end

  def llenar(hash)
    self.atributos_persistibles = hash.select{|key, value| self.has_key?(key)}.map do |key,value|
      [key,self.to_object(key,value)]
    end
    self
  end

  # punto 2
  def has_key?(key)
    self.class.has_key?(key)
  end

  private
  def borrar_entrada
    raise PersistibleNoGuardado.new(self) unless self.respond_to?(:id)
    self.class.table.delete(self.id)
  end

end

module ClaseDePersistible

  attr_reader :diccionario_de_tipos

  def self.extended(base)
    base.send(:diccionario_de_tipos=,{:id => String})
  end

  def table
    @table.nil? ? @table = TADB::DB.table(self.to_s) : @table
  end

  def has_one(tipo, descripcion)
    nombre_atributo = descripcion[:named]

    self.define_method(nombre_atributo) do
      self.atributos_persistibles[nombre_atributo]
    end

    self.define_method(nombre_atributo.to_s+"=") do |valor|
      self.atributos_persistibles[nombre_atributo] = valor
    end

    self.diccionario_de_tipos[nombre_atributo] = tipo
  end

  def has_key?(key)
    self.diccionario_de_tipos.key?(key)
  end

  def all_entries
    self.table.entries
  end



  def find_entries_by(atributo_sym,valor)
    self.all_entries.select do |hash|
      hash[atributo_sym] == valor
    end
  end

  private
  attr_writer :diccionario_de_tipos

end


module Boolean

end

################ Clases persistibles ###############

class Nota
  include Persistible

  has_one Numeric, named: :value
end

class Student
  include Persistible

  has_one String, named: :full_name
  has_one Nota, named: :grade
end


class Person
  include Persistible

  has_one String, named: :first_name
  has_one String, named: :last_name
  has_one Numeric, named: :age
  has_one Boolean, named: :admin

  def mayor
    self.age > 18
  end

end

class Main
  thomi = Person.new
  thomi.first_name = "Thomi"

end