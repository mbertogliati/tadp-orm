class Prueba
  def materia
    :tadp
  end
end

class Class
  def has_one(tipo, descripcion)
    # donde tipo es un tipo básico
    # y descripción es un hash con el nombre del atributo
    self.define_method(descripcion[:named]) do
      self.instance_variable_get("@"+descripcion[:named].to_s)
    end
    self.define_method(descripcion[:named].to_s+"=") do |valor|
      self.instance_variable_set(("@"+descripcion[:named].to_s).to_sym,valor)
    end
  end
end
