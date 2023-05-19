require 'tadb'

class PersistibleNoGuardado < Exception
  attr_accessor :objeto
end




module Persistible
  # punto 1

  attr_accessor :atributos_persistibles

  def self.included(base)
    base.extend(ClaseDePersistible)
  end

  def initialize
    self.atributos_persistibles = {}
  end

  def id
    self.atributos_persistibles[:id]
  end

  def save!(quien_llama = nil)
    # Si no hay id, necesito si o si el id para hacer el guardado
    if self.id.nil?
      self.atributos_persistibles[:id] = self.insertar({})
    end
    #Siempre al guardar hay que borrar la entrada anterior
    self.borrar_entrada

    diccionario_para_guardar = self.atributos_persistibles.to_h do |key,value|
      [key,self.guardar_y_convertir_a_valor(value)]
    end

    self.atributos_persistibles[:id] = self.insertar(diccionario_para_guardar)
  end

  def refresh!
    raise PersistibleNoGuardado.new(self) if self.id.nil?
    self.llenar(self.class.find_entries_by(:id, self.id).first)
    self
  end

  def forget!(quien_llama = nil)
    self.borrar_entrada
    self.atributos_persistibles[:id] = nil
  end

  def llenar(hash)
    atributos_persistibles[:id] = hash[:id]
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
    self.class.table.delete(self.id)
  end


  def guardar_y_convertir_a_valor(objeto)
    if objeto.is_a? Persistible
      objeto.save!(self)
    else
      objeto
    end
  end

  def convertir_valor_a_objeto(key,valor)
    tipo = self.class.diccionario_de_tipos[key]
    if tipo.ancestors.include? Persistible
      tipo.find_by_id(valor,self).first
      else
      valor
    end
  end

  private
  def obtener_atributo(sym)
    self.atributos_persistibles[sym]
  end

  private
  def setear_atributo(sym,valor)
    self.atributos_persistibles[sym] = valor
  end

  private
  def insertar(diccionario)
    self.class.table.insert(diccionario)
  end
  private
end

class ArrayDePersistible
  #include Persistible


  attr_reader :tabla_intermedia, :clase_que_llama, :lista_de_persistibles,:tipo
  attr_writer :lista_de_persistibles
  def initialize(clase_que_llama,tipo)
    self.clase_que_llama= clase_que_llama
    self.tipo= tipo
    self.tabla_intermedia = TADB::DB.table(clase_que_llama.to_s+"PorCada"+tipo.to_s)
    self.lista_de_persistibles= nil
    super()
  end

  def is_a?(clase)
    clase == Persistible || super
  end

  def ancestors
    [self,Persistible]
  end
  def save!(quien_llama)
    idClase = ("id"+clase_que_llama.to_s).to_sym
    idTipo = ("id"+tipo.to_s).to_sym

    self.lista_de_persistibles.each do |persistible|
      self.borrar_entrada(quien_llama.id,persistible.save!(self))
      self.tabla_intermedia.insert({ idClase=> quien_llama.id, idTipo => persistible.id})
    end
    "El Cacas"
  end

  def refresh!
    self.lista_de_persistibles.each do |persistible|
      persistible.refresh!
    end
    self.lista_de_persistibles
  end

  def forget!(quien_llama)
    self.borrar_entradas(quien_llama.id)
    self.lista_de_persistibles = []
  end

  def find_by_id(valor = nil,quien_llama)
    entradas = self.tabla_intermedia.entries.select do |hash|
      hash[("id"+clase_que_llama.to_s).to_sym] == quien_llama.id

    end
    lista_atributos = entradas.map do |hash|
      tipo.find_by_id(hash[("id"+tipo.to_s).to_sym],self).first
    end

    array_de_persistible = ArrayDePersistible.new(clase_que_llama,tipo)
    array_de_persistible.lista_de_persistibles = lista_atributos
    [array_de_persistible]
  end

  def get_valor(valor)
    valor.lista_de_persistibles
  end

  def set_nuevo_valor(valor, quien_llama)
    #self.borrar_entradas(quien_llama.id)
    self.lista_de_persistibles = valor
    self
  end

  private
  def borrar_entradas(id_clase)
    unless id_clase.nil?
      self.tabla_intermedia.entries.select{|hash| hash[("id"+clase_que_llama.to_s).to_sym] == id_clase}.each do |hash|
        self.tabla_intermedia.delete(hash[:id])
      end
    end
  end

  private
  def borrar_entrada(is_clase,id_tipo)
    entradas = self.tabla_intermedia.entries.select do |hash|
        hash[("id"+clase_que_llama.to_s).to_sym] == is_clase && hash[("id"+tipo.to_s).to_sym] == id_tipo
    end
    entradas.each do |hash|
      self.tabla_intermedia.delete(hash[:id])
    end
  end
  private

  private def convertir_valor_a_objeto(key, valor)

  end

  private def guardar_y_convertir_a_valor(objeto)

  end

  private
  attr_writer :tabla_intermedia, :clase_que_llama, :tipo
end


module ClaseDePersistible

  attr_reader :diccionario_de_tipos

  @@default_admin_de_valores = Class.new do
    def get_valor(valor)
      valor
    end

    def set_nuevo_valor(valor,quien_llama=nil)
      valor
    end
  end.new

  def self.extended(base)
    base.send(:diccionario_de_tipos=,{:id => String})
  end

  def table
    @table.nil? ? @table = TADB::DB.table(self.to_s) : @table
  end

  def has_many(tipo, descripcion)
    array_persistible = ArrayDePersistible.new(self,tipo)
    self.has_one(array_persistible, descripcion)

  end


  def has_one(tipo, descripcion)
    nombre_atributo = descripcion[:named]

    admin_valores = self.obtener_admin_de_valores(tipo)

    self.define_method(nombre_atributo) do#Altos nombres horribles pero ya estoy quemado necesito que ande
      admin_valores.get_valor(self.atributos_persistibles[nombre_atributo])
    end

    self.define_method(nombre_atributo.to_s+"=") do |valor|
      self.atributos_persistibles[nombre_atributo] = admin_valores.set_nuevo_valor(valor, self)
    end

    self.diccionario_de_tipos[nombre_atributo] = tipo
  end

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

  protected
  def obtener_admin_de_valores(tipo)
    if tipo.respond_to? :set_nuevo_valor and tipo.respond_to? :get_valor
      tipo
    else
      @@default_admin_de_valores
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

class Materia
  include Persistible

  has_one String, named: :nombre
  has_many Nota, named: :notas
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