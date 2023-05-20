require 'tadb'

class PersistibleNoGuardado < Exception
  attr_accessor :objeto

  def initialize(objeto)
    self.objeto = objeto
  end
end
class PersistibleInvalido < Exception
  attr_accessor :objeto

  def initialize(objeto)
    self.objeto = objeto
  end
end


module Persistible
  # punto 1

  attr_accessor :atributos_persistibles
  attr_accessor :atributos_has_many


  #TODO: Logica repetida
  def self.included(quien_llama)#
    quien_llama.extend(ClaseDePersistible)
    nombre_metodo = :included
    if quien_llama.is_a? Class
      nombre_metodo = :inherited
    end
    quien_llama.define_singleton_method(nombre_metodo) do |base|
      base.include(Persistible)
      self.agregar_descendiente(base)
      self.ancestors[1].send(:agregar_descendiente,base)
      super(base)
    end
  end

  def self.agregar_descendiente(base)
  end
  def self.diccionario_de_tipos
    {}
  end

  def delete_entries_by(atributo_sym, valor)
    self.table.delete_if { |hash| hash[atributo_sym] == valor }
  end

  def initialize
    self.atributos_persistibles = {}
    self.atributos_has_many = {}
    self.atributos_persistibles[:id] = nil
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


    atributos_has_many.each do |key, _|
      self.save_many!(key)
    end

    self.id
  end

  def save_many!(key_lista)

    self.borrar_entradas_many(key_lista)

    values = self.atributos_has_many[key_lista]

    if values.length > 0

      ids_elementos_lista = values.map do |element|
        self.guardar_y_convertir_a_valor(element)
      end

      lista_hash_insertar = get_lista_hashes(ids_elementos_lista,key_lista)

      # Si la tabla está ya creada me devuelve la tabla existente, y si no la crea para el nuevo atributo
      tipo_persistido = self.class.diccionario_de_tipos[key_lista]
      tabla_intermedia = self.class.get_tabla_intermedia(tipo_persistido)

      lista_hash_insertar.each do |hash_insertar|
        tabla_intermedia.insert(hash_insertar)
      end
    end
  end

  def refresh!
    raise PersistibleNoGuardado.new(self) if self.id.nil?
    self.atributos_persistibles = self.class.find_entries_by(:id, self.id).first
    self
  end

  def forget!
    self.borrar_entrada
    self.obtener_diccionario_tipos_has_many.each do |nombre_atributo, |
      self.borrar_entradas_many(nombre_atributo)
    end

    self.atributos_persistibles[:id] = nil
  end

  def validate!
    atributos_simples_validos =
    self.atributos_persistibles.map do |key, value|
      bool = value&.class == self.class.diccionario_de_tipos[key]
      bool
  end.all?

    atributos_many_validos =
      self.atributos_has_many.map do |key, value|
      value.all? do |elem|
        elem.class == self.class.diccionario_de_tipos[key]
      end
    end.all?
    unless atributos_simples_validos && atributos_many_validos
      raise PersistibleInvalido.new(self)
    end
  end

  def llenar(hash) #################################################################################
    #Aca se asume que se carga el ID
    self.atributos_persistibles = hash.select{|key, value| self.has_key?(key)}.to_h do |key,value|
      [key,self.convertir_valor_a_objeto(key,value)]
    end
    self.atributos_has_many = self.obtener_diccionario_ids.map do |key, value|
      [key,self.convertir_valores_a_objetos(key,value)]
    end.to_h
    self
  end

  # punto 2
  def has_key?(key)
    self.atributos_persistibles.has_key?(key) || self.class.has_key?(key)
  end

  def obtener_diccionario_ids()
    tablas_intermedias = self.class.tablas_intermedias
    self.obtener_diccionario_tipos_has_many.map do |nombre_atributo, tipo|
      nombre = "id#{tipo.to_s}"
      lista_ids = tablas_intermedias[tipo.to_s.to_sym].entries.map do |entrada|
       entrada[nombre.to_sym]
      end
      [nombre_atributo,lista_ids]
    end

  end

  def get_lista_hashes(ids_elementos_lista,key_lista)
    nombre_id_clase_padre = "id#{self.class.to_s}".to_sym
    nombre_id_tipo_persistido = "id#{self.class.diccionario_de_tipos[key_lista]}".to_sym
    ids_elementos_lista.map do |elem|
      {nombre_id_clase_padre => self.id, nombre_id_tipo_persistido => elem}
    end
  end

  def atributos_persistibles
    @atributos_persistibles
  end

  private
  def borrar_entrada
    self.class.table.delete(self.id)
  end

  def obtener_diccionario_tipos_has_many
    tablas_intermedias = self.class.tablas_intermedias

    self.class.diccionario_de_tipos.select do |_, tipo|
      tablas_intermedias.has_key?(tipo.to_s.to_sym)
    end
  end

  def borrar_entradas_many(key_lista)
    tipo_persistido = self.class.diccionario_de_tipos[key_lista]
    tabla_intermedia = self.class.get_tabla_intermedia(tipo_persistido)

    tabla_intermedia.entries.select do |entrada|
      entrada["id#{self.class.to_s}".to_sym] == self.id
    end.map do |entrada|
      tabla_intermedia.delete(entrada[:id])
    end
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
    if tipo and tipo.ancestors.include? Persistible
      tipo.find_by_id(valor).first
      else
      valor
    end
  end

  def convertir_valores_a_objetos(key,lista_ids)
    tipo = self.class.diccionario_de_tipos[key]
    if tipo and tipo.ancestors.include? Persistible
      lista_ids.map do |id|
        tipo.find_by_id(id).first
      end
    else
      lista_ids
    end
  end

  def method_missing(sym, *args, &block)
    sym_base = sym.to_s.sub("=", "").to_sym
    if self.has_key?(sym_base)
      if sym.to_s.end_with?("=") and args.size == 1
        self[sym_base] = args.first
      else if args.size == 0
        self[sym_base]
        end
      end
    else
      super
    end

  end

  def respond_to_missing?(nombre_metodo, include_private = false)
    sym_base = nombre_metodo.to_s.sub("=", "").to_sym
    self.has_key?(sym_base) || super
  end

end

module ClaseDePersistible

  attr_reader :diccionario_de_tipos,:tablas_intermedias

  def self.extended(base)
    base.instance_variable_set(:@diccionario_de_tipos, base.ancestors[1].diccionario_de_tipos)
    base.instance_variable_set(:@tablas_intermedias, {})
    base.instance_variable_set(:@descendientes, [])
  end

  def table
    @table.nil? ? @table = TADB::DB.table(self.to_s) : @table
  end
  def has_many(tipo, descripcion)
    nombre_lista = descripcion[:named]
    self.diccionario_de_tipos[nombre_lista] = tipo
    self.crear_tabla_intermedia(tipo)

    # Definir el getter para acceder a la lista de objetos relacionados
    self.define_method(nombre_lista) do
      self.atributos_has_many[nombre_lista] ||= []
      self.atributos_has_many[nombre_lista]
    end

    self.define_method(nombre_lista.to_s+"=") do |valor|
      self.atributos_has_many[nombre_lista] = valor
    end

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

  def get_tabla_intermedia(tipo)
      self.tablas_intermedias[tipo.to_s.to_sym]
  end

  def crear_tabla_intermedia(tipo)
    self.tablas_intermedias[tipo.to_s.to_sym] = TADB::DB.table("#{tipo.to_s}PorCada#{self.to_s}")
  end

  def find_entries_by(atributo_sym,valor)
    self.all_entries.select do |hash|
      hash[atributo_sym] == valor
    end
  end
  def all_instances
    lista_hash = self.all_entries

    lista_instancias = lista_hash.map! do |hash|
      instancia = self.new
      instancia.llenar(hash)
    end
    lista_instancias + self.instancias_de_descendientes

  end
  def delete_entries_by(atributo_sym, valor)
    self.all_entries.delete_if { |hash| hash[atributo_sym] == valor }
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

  def insertar(valor)
    self.table.insert(valor)
  end

  protected
  def diccionario_por_id(id,tipo)
    self.get_tabla_intermedia(tipo).entries.select do |hash|
      hash[:id] == id
    end
  end

  private

  def agregar_descendiente(descendiente)
    @descendientes << descendiente
  end

  def instancias_de_descendientes
    @descendientes.map do |descendiente|
      descendiente.all_instances
    end.flatten
  end

  attr_writer :diccionario_de_tipos,:tablas_intermedias

end


module Boolean

end

################ Clases persistibles ###############


# No existe una tabla para las Personas, porque es un módulo.
class Grade
  include Persistible
  has_one Numeric, named: :value
end

module Person
  include Persistible
  has_one String, named: :full_name
end
class Student
  include Person
  has_one Grade, named: :grade
end
# Hay una tabla para los Alumnos con los campos id, nombre y nota.

# Hay una tabla para los Ayudantes con id, nombre, nota y tipo

class AssistantProfessor < Student

  has_one String, named: :type

end





class Main

  profesor = AssistantProfessor.new
  profesor.full_name = "Juan"
  profesor.grade = 10
  profesor.type = "Ayudante"
  #profesor.save!

  estudiante = Student.new
  estudiante.full_name = "Pedro"
  estudiante.grade = Grade.new
  estudiante.validate!
  #estudiante.save!

  puts Person.all_instances.first.full_name

end

