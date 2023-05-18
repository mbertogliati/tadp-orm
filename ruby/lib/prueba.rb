require 'tadb'

class PersistibleNoGuardado < Exception
  attr_accessor :objeto


  def initialize(objeto)
    self.objeto = objeto
  end
end

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


module Persistible
  # punto 1

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
    if self.id != nil
      self.borrar_entrada
    end

    diccionario_para_guardar = self.atributos_persistibles.to_h do |key,value|
      [key,self.guardar_y_convertir_a_valor(value)]
    end

    self.atributos_persistibles[:id] = self.class.insertar(diccionario_para_guardar)
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

  def llenar(hash)
    self.atributos_persistibles = hash.select{|key, value| self.has_key?(key)}.to_h do |key,value|
      [key,self.convertir_valor_a_objeto(key,value)]
    end
    self
  end

  # punto 2
  def has_key?(key)
    self.class.has_key?(key)
  end

  private
  def borrar_entrada
    self.atributos_persistibles[:id] = nil
    self.class.table.delete(self.id)
  end

  def guardar_y_convertir_a_valor(objeto)
    if objeto.is_a? Persistible
      objeto.save!
    else
      objeto
    end
  end

  def convertir_valor_a_objeto(key,valor)
    tipo = self.class.diccionario_de_tipos[key]
    if tipo.ancestors.include? Persistible
      tipo.find_by_id(valor).first
      else
      valor
    end
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

  def has_many(tipo, descripcion)
    nombre_lista = descripcion[:named]

    self.diccionario_de_tipos[nombre_lista] = [tipo]

    #Student_Materia
    tabla_intermedia = crear_tabla_intermedia(tipo)

    # Person {nombre: santi, id: 1, materias: [1, 2, 3]}
    # Person_materias {1,1}{1,2}{1,3}
    # Materia {id:1, nombre: matematica}{id:2, nombre:lengua}


  end

  def has_many2(tipo, descripcion)
    nombre_atributo = descripcion[:named]

    define_method(nombre_atributo) do
      # Obtener las entradas relacionadas desde la tabla intermedia
      tabla_intermedia = self.class.table_intermedia(tipo)
      ids = tabla_intermedia.find_entries_by(self.class.to_s.downcase.to_sym, self.id).map { |hash| hash[:id] }
      tipo.find_entries_by(:id, ids)
    end

    define_method(nombre_atributo.to_s + "=") do |valores|
      # Guardar las entradas relacionadas en la tabla intermedia
      tabla_intermedia = self.class.tabla_intermedia(tipo)
      tabla_intermedia.delete_entries_by(self.class.to_s.downcase.to_sym, self.id)
      valores.each do |valor|
        tabla_intermedia.insert({ self.class.to_s.downcase.to_sym => self.id, tipo.to_s.downcase.to_sym => valor.id })
      end
    end
  end


  def crear_tabla_intermedia(tipo)
    tabla_intermedia = TADB::DB.table("#{self.to_s.downcase}_#{tipo.to_s.downcase}")

    tabla_intermedia
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

  def insertar(valor)
    self.table.insert(valor)
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

class Materia
  include Persistible

  has_one String, named: :nombre
end

class Student
  include Persistible

  has_many Materia, named: :materias
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