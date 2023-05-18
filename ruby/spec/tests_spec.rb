require 'rspec'
require_relative '../lib/prueba.rb'

describe 'Clase de Persistible' do

  describe 'Todas las Clases de Persistible' do
  before(:example) do
    @miClasePersistible = Class.new.extend(ClaseDePersistible)
  end

  it 'tienen tabla asociada' do
    expect(@miClasePersistible.table.is_a? TADB::Table).to be true
  end

  it 'tienen diccionario de tipos' do
    expect(@miClasePersistible.diccionario_de_tipos.is_a? Hash).to be true
  end

  it 'entienden el mensaje has_key?' do
    expect(@miClasePersistible.respond_to?(:has_key?)).to be true
  end

  describe "entienden el mensaje has_one" do
    before(:example) do
      expect(@miClasePersistible.respond_to?(:has_one)).to be true
    end

    it 'y agregan las claves a su diccionario de tipos cada vez que se lo llama' do

      claves = {:string1 => String, :string2 => String, :numero => Integer}

      claves.each do |key,value|
        @miClasePersistible.has_one(value, named: key)
      end

      expect(claves.all? {|key,value| @miClasePersistible.diccionario_de_tipos.has_key?(key) && @miClasePersistible.diccionario_de_tipos[key] == value}).to be true
    end

  end

    it 'entienden el mensaje all_entries' do
      expect(@miClasePersistible.respond_to?(:all_entries)).to be true
    end

    it 'entienden el mensaje find_entries_by' do
      expect(@miClasePersistible.respond_to?(:find_entries_by)).to be true
    end
  end
  it 'Las Clases que incluyen a Persistible son Clases de Persistible' do
    expect(Class.new.include(Persistible).is_a? ClaseDePersistible).to be true
  end
end

describe 'Persistible' do

  before(:context) do
    @clase_de_persistible = Class.new.include(Persistible)
    otra_clase_persistible = Class.new.include(Persistible)
    otra_clase_persistible.define_singleton_method(:to_s) do
      "OtraClasePersistiblePrueba"
    end
    otra_clase_persistible.has_one(String, named: :string3)
    otra_clase_persistible.has_one(String, named: :string4)
    otra_clase_persistible.has_one(Integer, named: :numero2)

    instancia1 = otra_clase_persistible.new
    instancia1.string3 = "hola"
    instancia1.string4 = "chau"
    instancia1.numero2 = 1


    @clase_de_persistible.has_one(String, named: :string1)
    @clase_de_persistible.has_one(String, named: :string2)
    @clase_de_persistible.has_one(Integer, named: :numero)
    @clase_de_persistible.has_one(otra_clase_persistible, named: :otro_persistible)

    @clase_de_persistible.define_singleton_method(:to_s) do
      "ClaseDePersistiblePrueba"
    end

    @clase_de_persistible.define_singleton_method(:to_s) do
      "ClaseDePersistiblePrueba"
    end

  end

  describe 'Todos los Persistibles' do
    before(:context) do
      @mi_persistible = @clase_de_persistible.new
    end

    it 'tienen atributos persistibles' do
      expect(@mi_persistible.respond_to?(:atributos_persistibles)).to be true
      expect(@mi_persistible.atributos_persistibles.is_a? Hash).to be true
    end

    it 'entienden siempre todos los mensajes asociados a los atributos definidos en su clase (menos setter de id)' do

      @mi_persistible.class.diccionario_de_tipos.each do |key,value|
          expect(@mi_persistible.respond_to?(key)).to be true
          if key != :id
            expect(@mi_persistible.respond_to?("#{key}=")).to be true
          end
      end
    end

    it 'entienden el mensaje refresh!' do
      expect(@mi_persistible.respond_to?(:refresh!)).to be true
    end

    it 'entienden el mensaje forget!' do
      expect(@mi_persistible.respond_to?(:forget!)).to be true
    end

    it 'entienden el mensaje save!' do
      expect(@mi_persistible.respond_to?(:save!)).to be true
    end

  end

  describe 'Los Persistibles guardados' do
    before(:context) do
      @mi_persistible = @clase_de_persistible.new

      otro_persitible = @clase_de_persistible.diccionario_de_tipos[:otro_persistible].new

      expect(@mi_persistible.respond_to?(:save!)).to be true
      @mi_persistible.string1 = "string1"
      @mi_persistible.string2 = "string2"
      @mi_persistible.numero = 1

      otro_persitible.string3 = "hola"
      otro_persitible.string4 = "chau"
      otro_persitible.numero2 = 2

      @mi_persistible.otro_persistible = otro_persitible

      @mi_persistible.class.table.clear

      @id = @mi_persistible.save!
    end

    it 'al guardarlos devuelven el id' do
      expect(@id).to be @mi_persistible.atributos_persistibles[:id]
    end

    it 'tienen sus atributos persistibles guardados en la tabla de su clase' do
      expect(@mi_persistible.atributos_persistibles[:otro_persistible].is_a? Persistible).to be true
      hash_con_valores = @mi_persistible.atributos_persistibles.to_h do |key,value|
        if value.is_a? Persistible
          [key,value.id]
        else
          [key,value]
        end
      end
      expect(@mi_persistible.class.all_entries.first).to eq hash_con_valores

      #TODO: A priori esto se cumple hasta que se agregue lo de composicion
    end

    it 'tienen asignado un id' do
      expect(@mi_persistible.respond_to?(:id)).to be true
      expect(@mi_persistible.id).to be @mi_persistible.atributos_persistibles[:id]
    end

    it 'pueden ser refrescados si se modifican sus atributos' do
      @mi_persistible.string1 = "string1 modificado"
      @mi_persistible.refresh!
      expect(@mi_persistible.string1).to eq "string1"
    end

    describe 'pueden ser borrados' do
      before(:context) do
        @mi_persistible.forget!
      end

      it 'y ya no tendran id' do
        expect(@mi_persistible.id).to be nil
      end

    end

  end

  describe 'Los Persistibles no guardados' do
    before(:context) do


      @mi_persistible = @clase_de_persistible.new

      @mi_persistible.string1 = "string1"
      @mi_persistible.string2 = "string2"
      @mi_persistible.numero = 1

      @mi_persistible.class.table.clear

    end

    it 'no tienen asignado un id' do
      expect(@mi_persistible.id).to be nil
    end

    it 'dan error al intentar ser refrescados' do
      expect{@mi_persistible.refresh!}.to raise_error(PersistibleNoGuardado)
    end

    it 'pueden ser borrados' do
      expect(@mi_persistible.forget!).to be(nil)
    end

  end

  describe 'Todas las Clases que incluyen a Persistible' do

    before(:context) do
      @misPersistibles = []

      @n = 6

      @n.times do |i|
        @mi_persistible = @clase_de_persistible.new
        @mi_persistible.string1 = "string"+i.to_s
        @mi_persistible.string2 = "string"+i.to_s
        @mi_persistible.numero = i
        @mi_persistible.save!
        @misPersistibles.push(@mi_persistible)
      end

    end

    it 'pueden recuperar todos los objetos guardados' do
      objetos_recuperados = @clase_de_persistible.all_instances
      expect(objetos_recuperados.size).to be @n
      expect(@clase_de_persistible.all_entries.size).to be @n
      expect(@clase_de_persistible.all_entries).to eq @misPersistibles.map{|persistible| persistible.atributos_persistibles}

      objetos_recuperados.all? do |objetoRecuperado|
        expect(objetoRecuperado.is_a? @clase_de_persistible).to be true
      end

      objetos_recuperados.zip(@misPersistibles).all? do |objetoRecuperado, objetoOriginal|
        objetoRecuperado.atributos_persistibles == objetoOriginal.atributos_persistibles
      end

    end

    it 'entienden todos los mensajes de tipo find_by_{atributo}' do
      @clase_de_persistible.diccionario_de_tipos.each do |key,value|
        expect(@clase_de_persistible.send(:respond_to_missing?, "find_by_#{key}")).to be true
      end
    end

  end

end
