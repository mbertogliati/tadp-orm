require 'tadb'

module Persistible
  # punto 1 - a
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

    atributos_persisitbles = self.instance_variables.select do
    |atributo| self.instance_variable_get(atributo).is_a? AtributoPersistible
    end

    hash_values = {}

    atributos_persisitbles.each do |atributo|
      hash_values[atributo.to_s.gsub("@","").to_sym] = self.instance_variable_get(atributo).valor
    end

    #puts hash_values

    self.definir_metodo_id

    self.id= self.class.table.insert(hash_values)

  end



  def definir_metodo_id
    self.define_singleton_method("id") do
      @id
    end
  end

  def borrar_metodo_id
    self.singleton_class.remove_method("id")
  end

  def refresh!
    self.borrar_tabla
    self.save!
  end

  def forget!
    self.borrar_tabla
    self.borrar_metodo_id
  end

  private
  def borrar_tabla
    self.class.table.delete(@id)
  end

  private :id=

end

class AtributoPersistible
  attr_accessor :tipo, :valor
  def initialize(tipo, valor)
    @tipo = tipo
    @valor = valor
  end

  def valor= (valor)
    @valor = valor
  end

end

module ClasePersistible

  def table
    @table.nil? ? @table = TADB::DB.table(self.to_s) : @table
  end
  def has_one(tipo, descripcion)

    self.define_method(descripcion[:named]) do
      atributo = self.instance_variable_get("@"+descripcion[:named].to_s)
      atributo.valor
    end

    self.define_method(descripcion[:named].to_s+"=") do |valor|
      self.instance_variable_set(("@"+descripcion[:named].to_s),AtributoPersistible.new(tipo, valor))
    end

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


module Boolean

end

class Class
  def include(*args)
    if args.include? Persistible
      #Le setea la singleton_class
      self.extend(ClasePersistible)
    end
    super
  end
end
class Person

  include Persistible

  has_one String, named: :first_name
  has_one String, named: :last_name
  has_one Numeric, named: :age
  has_one Boolean, named: :admin

end



class Main
  persona1 = Person.new
  persona1.first_name= "Thomy"
  persona1.last_name= "Pereyra"

  persona2 = Person.new
  persona2.first_name= "Milagros"
  persona2.last_name= "Pereyra"

  persona3 = Person.new
  persona3.first_name= "Mateo"
  persona3.last_name= "Pereyra"

  #puts Person.table

  persona1.save!
  persona2.save!
  persona3.save!

  puts Person.all_instances

  #puts Person.table.instance_variable_get(:@name)

end