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

class TipoInvalido < Exception
  attr_accessor :tipo

  def initialize(tipo)
    self.tipo = tipo
    msg = "El tipo " + tipo.to_s + " no puede ser persistido."
    super(msg)
  end

end

module Boolean

end
class TrueClass
  include Boolean
end
class FalseClass
  include Boolean
end

module Persistible
  # punto 1

  attr_accessor :atributos_has_one
  attr_accessor :atributos_has_many


  def self.included(quien_llama)#
    quien_llama.extend(ClaseDePersistible) #ClaseDePersistible.extended(self)

  end

  #TODO: Refactorizar
  def self.agregar_descendiente(base)
  end
  def self.diccionario_de_tipos
    {}
  end
  def self.tablas_para_descendiente(base)
    {}
  end
  def self.defaults
    {}
  end
  def self.validadores
    {}
  end

  def ==(otro_objeto)
    if !self.id.nil? && (otro_objeto.is_a? Persistible) && !otro_objeto.id.nil?
      self.id == otro_objeto.id
    else
      super
    end
  end

  def delete_entries_by(atributo_sym, valor)
    self.table.delete_if { |hash| hash[atributo_sym] == valor }
  end

  def initialize
    self.atributos_has_one = {}
    self.atributos_has_many = {}
    self.atributos_has_one[:id] = nil
  end

  def id
    self.atributos_has_one[:id]
  end

  def save!
    # En caso de que ya haya hecho un save previo, sobreescribo el registro en la tabla
    self.set_defaults
    self.validate!

    if self.id != nil
      self.borrar_entrada
    end

    diccionario_para_guardar = self.atributos_has_one.to_h do |key,value|
      [key,self.guardar_y_convertir_a_valor(value)]
    end

    self.atributos_has_one[:id] = self.class.insertar(diccionario_para_guardar)



    atributos_has_many.each do |key, _|
      self.save_many!(key)
    end

    self.id
  end

  def save_many!(key_lista)

    self.borrar_entradas_many(key_lista)

    values = self.atributos_has_many[key_lista]

    if values.length > 0

      ids_elementos_lista = values.map do |value|
        self.guardar_y_convertir_a_valor(value)
      end

      lista_hash_insertar = get_lista_hashes(ids_elementos_lista,key_lista)

      # Si la tabla está ya creada me devuelve la tabla existente, y si no la crea para el nuevo atributo
      tabla_intermedia = self.class.get_tabla_intermedia(key_lista)

      lista_hash_insertar.each do |hash_insertar|
        tabla_intermedia.insert(hash_insertar)
      end
    end
  end

  def refresh!
    raise PersistibleNoGuardado.new(self) if self.id.nil?
    instancia_refrescada = self.class.find_by_id(self.id).first
    self.atributos_has_one = instancia_refrescada.atributos_has_one
    self.atributos_has_many = instancia_refrescada.atributos_has_many

    self
  end

  def forget!
    self.borrar_entrada
    self.obtener_diccionario_tipos_has_many.each do |nombre_atributo, |
      self.borrar_entradas_many(nombre_atributo)
    end

    self.atributos_has_one[:id] = nil
  end
  def validate!
    #TODO: Logica Repetida
    atributos_validos = self.class.diccionario_de_tipos.map do |key, _|
        if self.class.tablas_intermedias.has_key?(key)
          #Validar array
          valor = atributos_has_many[key]
          valor ||= []
          self.validar_tipos(key, valor) && self.ejecutar_validadores(key,valor)
        else
          #Validar simple
          valor = self.atributos_persistibles[key]
          self.validar_tipos(key, valor) && self.ejecutar_validadores(key, valor)
        end
    end.all?


  end

  def validar_tipos(key, value)
    if value.is_a? Array
      value.all? do |elem|
        !elem.nil? && (elem.is_a? self.class.diccionario_de_tipos[key])
      end
      else
    value.nil? || (value.is_a? self.class.diccionario_de_tipos[key])
    end
  end

  def ejecutar_validadores(key,valor)
    unless( self.class.validadores[key].empty?)
      self.class.validadores[key].all? do |validador|
        if valor.is_a? Persistible
          valor.validate!
        end
        validador.validar(valor)
      end
    else
      true
    end
  end

  def llenar(hash) #################################################################################
    #Aca se asume que se carga el ID
    self.atributos_has_one = hash.select{|key, value| self.has_key?(key)}.to_h do |key,value|
      [key,self.convertir_valor_a_objeto(key,value)]
    end
    self.atributos_has_many = self.obtener_diccionario_ids.map do |key, value|
      [key,self.convertir_valores_a_objetos(key,value)]
    end.to_h
    self
  end

  # punto 2
  def has_key?(key)
    self.atributos_has_one.has_key?(key) || self.class.has_key?(key)
  end

  def obtener_diccionario_ids() #Obtengo los diccionarios de la forma {idAtributo => "sdewihd9q8h23dbjasndiuh1x2379vdw9auqjn"} ej {idMateria => "sdewihd9q8h23dbjasndiuh1x2379vdw9auqjn"}
    tablas_intermedias = self.class.tablas_intermedias
    self.obtener_diccionario_tipos_has_many.map do |nombre_atributo, tipo|
      nombre = "id_#{nombre_atributo.to_s}"
      lista_ids = tablas_intermedias[nombre_atributo.to_s.to_sym].entries.select do |entrada|
         entrada["id_#{self.class.to_s}".to_sym] == self.id
      end.map do |entrada|
       entrada[nombre.to_sym]
      end
      [nombre_atributo,lista_ids]
    end

  end

  def get_lista_hashes(ids_elementos_lista,key_lista)
    nombre_id_clase_padre = "id_#{self.class.to_s}".to_sym
    nombre_id_tipo_persistido = "id_#{key_lista.to_s}".to_sym
    ids_elementos_lista.map do |elem|
      {nombre_id_clase_padre => self.id, nombre_id_tipo_persistido => elem}
    end
  end

  def atributos_has_one
    @atributos_has_one
  end

  private

  def set_defaults
    self.class.diccionario_de_tipos.map do |key, value|
      if self.class.tablas_intermedias.has_key?(key)
        objeto = self.atributos_has_many[key]
        if objeto == [] && !self.class.defaults[key].nil?
          atributos_has_many[key] = self.class.defaults[key]
        end
      else
        objeto = self.atributos_has_one[key]
        if objeto.nil? && !self.class.defaults[key].nil?
          atributos_has_one[key] = self.class.defaults[key]
        end
      end
    end
  end

  def borrar_entrada
    self.class.table.delete(self.id)
  end

  def obtener_diccionario_tipos_has_many
    tablas_intermedias = self.class.tablas_intermedias

    result = self.class.diccionario_de_tipos.select do |nombre, _|
      tablas_intermedias.has_key?(nombre.to_s.to_sym)
    end
    result
  end

  def borrar_entradas_many(key_lista)
    tabla_intermedia = self.class.get_tabla_intermedia(key_lista)

    tabla_intermedia.entries.select do |entrada|
      entrada["id_#{self.class.to_s}".to_sym] == self.id
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

  attr_reader :diccionario_de_tipos,:tablas_intermedias,:table,:defaults,:validadores

  @@dummy_table = Object.new
  @@dummy_table.define_singleton_method(:entries) { [] } #TODO: Fijarse si esto es necesario
  @@tipos_validos = [Numeric, String, Boolean, Persistible]

  def self.extended(quien_llama)

    nombre_metodo = :included
    tabla_asignada = @@dummy_table
    if quien_llama.is_a? Class
      nombre_metodo = :inherited
      tabla_asignada = TADB::DB.table(quien_llama.to_s)
    end

    quien_llama.define_singleton_method(nombre_metodo) do |base|
      base.extend(ClaseDePersistible)
      self.agregar_descendiente(base)
      super(base)
    end
    quien_llama.instance_variable_set(:@diccionario_de_tipos, quien_llama.ancestors[1].diccionario_de_tipos.clone)
    quien_llama.instance_variable_set(:@tablas_intermedias, quien_llama.ancestors[1].tablas_para_descendiente(quien_llama).clone)
    quien_llama.instance_variable_set(:@validadores, quien_llama.ancestors[1].validadores.clone) #{:nombre_atributo => [validador1,validador2]
    quien_llama.instance_variable_set(:@descendientes, [])
    quien_llama.instance_variable_set(:@table, tabla_asignada)
    quien_llama.instance_variable_set(:@defaults, quien_llama.ancestors[1].defaults.clone)
  end

  def has_many(tipo, *params)
    self.validar_tipo(tipo)
    parametros = params.reduce({}, :merge)
    nombre_lista = parametros[:named]
    defaults[nombre_lista] = parametros[:default]
    self.diccionario_de_tipos[nombre_lista] = tipo

    self.crear_validadores(nombre_lista,parametros)


    self.crear_tabla_intermedia(nombre_lista)

    # Definir el getter para acceder a la lista de objetos relacionados TODO: Logica repetida
    self.define_method(nombre_lista) do
      self.atributos_has_many[nombre_lista] ||= parametros[:default] ? parametros[:default].dup : []
      self.atributos_has_many[nombre_lista]
    end

    self.define_method(nombre_lista.to_s+"=") do |valor|
      self.atributos_has_many[nombre_lista] = valor
    end

  end
  def has_one(tipo, *params)
    self.validar_tipo(tipo)
    parametros = params.reduce({}, :merge)
    nombre_atributo = parametros[:named]
    defaults[nombre_atributo] = parametros[:default]
    self.diccionario_de_tipos[nombre_atributo] = tipo
    self.crear_validadores(nombre_atributo,parametros)

    self.tablas_intermedias.delete(nombre_atributo)

    self.define_method(nombre_atributo) do
      self.atributos_has_one[nombre_atributo] ||= parametros[:default]
      self.atributos_has_one[nombre_atributo]
    end

    self.define_method(nombre_atributo.to_s+"=") do |valor|
      self.atributos_has_one[nombre_atributo] = valor
    end


  end


  def crear_validadores(nombre_atributo,parametros)

    self.validadores[nombre_atributo] = []
    self.validadores[nombre_atributo] << ValidadorNoBlank.new if parametros.has_key?(:no_blank)

    if (self.diccionario_de_tipos[nombre_atributo] != Numeric) && (parametros.has_key?(:from) || parametros.has_key?(:to))
      raise "No se puede validar un atributo no numerico con from o to" #TODO
    end

    self.validadores[nombre_atributo] << Validador.new(proc{ self <= parametros[:to] }) if parametros.has_key?(:to)
    self.validadores[nombre_atributo] << Validador.new(proc{ self >= parametros[:from] }) if parametros.has_key?(:from)

    self.validadores[nombre_atributo] << Validador.new(parametros[:validate]) if parametros.has_key?(:validate)

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

  #############################





  def tablas_para_descendiente(descendiente)
    tablas = {}
    self.tablas_intermedias.each do |key,tabla|
      if descendiente.is_a? Class
      tablas[key] = TADB::DB.table("#{descendiente.to_s}_#{key.to_s}")
      else
        tablas[key] = @@dummy_table
      end
    end
    tablas
  end

  #TODO: Revisar como se rompen los modulos cuando se intentan invocar metodos asociados a la tabla

  def insertar(valor)
    self.table.insert(valor)
  end

  def get_tabla_intermedia(nombre_atributo)
    self.tablas_intermedias[nombre_atributo.to_s.to_sym]
  end

  ###################
  private

  def validar_tipo(tipo)
    es_tipo_valido = @@tipos_validos.any? do |tipo_valido|
      tipo.ancestors.include?(tipo_valido)
    end

    raise TipoInvalido.new(tipo) unless es_tipo_valido

  end

  def all_entries
    self.table.entries
  end

  def find_by(atributo_sym,valor)
    self.all_instances.select { |instancia| instancia.send(atributo_sym) == valor }
  end

  def crear_tabla_intermedia(nombre_atributo)
    if self.is_a? Class
      self.tablas_intermedias[nombre_atributo.to_s.to_sym] = TADB::DB.table("#{self.to_s}_#{nombre_atributo.to_s}")
    else
      self.tablas_intermedias[nombre_atributo.to_s.to_sym] = @@dummy_table
    end
  end

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

class Validador
  def initialize(bloque)
    @bloque = bloque
  end
  def validar(valor)
    raise PersistibleInvalido.new(self) unless self.es_valido?(valor)
    self.es_valido?(valor)
  end

  def es_valido?(valor)
    if valor.is_a? Array
      valor.all?(&@bloque)
    else
      valor.instance_exec(&@bloque)
    end
  end

end

class ValidadorNoBlank

  def validar(valor)
    raise PersistibleInvalido.new(self) unless self.es_valido?(valor)
    self.es_valido?(valor)
  end

  def es_valido?(valor)
    if valor.is_a? Array
      valor != []
    else
      !(valor.nil? || valor == "" )
    end
  end


end

################ Clases persistibles ###############


# No existe una tabla para las Personas, porque es un módulo.



module LivingBeing
  include Persistible
  has_one String, named: :especie
end

class Alien
  include LivingBeing

  has_one String, named: :planeta
  has_many String, named: :ojos
end

class Grade
  include Persistible
  has_one Numeric, named: :value
  has_one String, named: :value
  has_many String, named: :value
  has_many Alien , named: :value
  has_one Numeric, named: :value, from: 1, to: 10, no_blank: true
  has_one Numeric, named: :value
  #has_one Array, named: :comments #TODO: Implementar una Excepcion propia para cuando un atributo no es ni persitible ni primitivo
end

module Person
  include LivingBeing  # persistible.included(self)
  has_many String, named: :objetos
  has_one String, named: :full_name, default: "Juan Perez"
end

#Person.all_instances ===> todos los students y todos los assistant professors

class Student
  include Person # person.included(self)
  has_one Grade, named: :grade
  has_many Grade, named: :historial, no_blank: true
end

class AsesinoSerial < Student
  has_many Alien, named: :personalidades
end

#[Student,Person,Object]
# Hay una tabla para los Alumnos con los campos id, nombre y nota.

# Hay una tabla para los Ayudantes con id, nombre, nota y tipo

class AssistantProfessor < Student
  has_one String, named: :type
end

class Main

  grade1= Grade.new
  grade1.value = 6


  alien1 = Alien.new
  alien1.especie = "Extraterrestre"
  alien1.planeta = "Saturno"
  alien1.ojos = ["verde","azul"]
  alien1.validate!

  #alien1.save!

  alien2 = Alien.new
  alien2.especie = "Extraterrestre"
  alien2.planeta = "Jupiter"
  alien2.ojos = ["marron","turquesa"]
  alien2.save!

  profesor = AssistantProfessor.new
  #profesor.full_name = "Nico"
  profesor.especie = "Humano"
  profesor.type = "Capo"
  profesor.objetos = ["cuchara","cafe"]
  profesor.historial= [grade1,grade1]
  profesor.save!

  estudiante = Student.new
  estudiante.full_name = "Pedro Pascal"
  estudiante.especie = "Humano"
  estudiante.grade = Grade.new
  estudiante.grade.value = 5
  estudiante.objetos = ["lapiz","cuaderno"]
  estudiante.historial= [grade1]
  estudiante.validate!
  estudiante.save!

  asesino = AsesinoSerial.new
  asesino.full_name= "Freddy Krueger"
  asesino.especie = "Humano"
  asesino.personalidades = [alien1,alien2]
  asesino.historial= [grade1]
  asesino.save!

  todos = Person.all_instances
  todos

  todos_vivos = LivingBeing.all_instances
  todos_vivos
  humanos = Student.find_by_objetos(["lapiz","cuaderno"])
  humanos
end

