require 'tadb'
module Persistible
  # punto 1 - a
  @table = TADB::DB.table(self.to_s)


  def save!
    self.define_singleton_method("id") do
      self.instance_variable_get("@"+"id".to_s)
    end
  end

  def refresh!

  end

  def forget!
    self.remove_method("id");
  end


end

module ClasePersistible
  def has_one(tipo, descripcion)
    self.define_method(descripcion[:named]) do
      self.instance_variable_get("@"+descripcion[:named].to_s)
    end
    self.define_method(descripcion[:named].to_s+"=") do |valor|
      self.instance_variable_set(("@"+descripcion[:named].to_s).to_sym,valor)
    end
  end
end


module Boolean

end

class Class
  def include(*args)
    if args.include? Persistible
      self.extend(ClasePersistible) //Le setea la singleton_class//
      self.instance_variable_set("@table", TADB::DB.table(self.to_s))
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
  persona = Person.new
  persona.first_name= "Thomy"

  puts persona.save!
end