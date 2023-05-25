require 'rspec'
require_relative '../lib/prueba.rb'

module Person
  include Persistible
  has_many String, named: :objetos
  has_one String, named: :full_name, default: "Juan Perez"
  end

class Grade
  has_one Numeric, named: :value
end

class Estudiante
  include Person
  has_one Numeric, named: :edad
  has_one Grade, named: :grade
  has_many Grade, named: :historial
end

class Profesor
  include Person
  has_one String, named: :materia  
  has_one Numeric, named: :edad
end

class Ayudante < Profesor
  has_one String, named: :type
end



describe 'ORM Tests' do

  before(:context) do
    @estudiante = Estudiante.new
    @estudiante2 = Estudiante.new
    @profesor = Profesor.new
  end


  describe 'Persistencia de objetos sencillos' do

    it 'definir atributo persistible has_one' do
      @estudiante.full_name= "Fran"
      expect(@estudiante.full_name).to eq("Fran")
    end

    it 'se pueden persistir y recuperar atributos' do
      @estudiante.full_name= "Fran"
      @estudiante.save!
      @estudiante.full_name= ""
      @estudiante.refresh!
      expect(@estudiante.full_name).to eq "Fran"
    end

    it 'forget!' do
      @estudiante.save!
      @estudiante.forget!
      expect(@estudiante.id).to eq nil
    end

  end

  describe 'Recuperacion y busqueda' do
    after(:example) do
      Estudiante.table.clear
      Grade.table.clear
    end
    it 'Se pueden recuperar todas las instancias persistidas de una clase' do

      @estudiante.save!
      @estudiante2.save!
      estudiantes = Estudiante.all_instances
      expect([@estudiante, @estudiante2].all? {|e| estudiantes.include? e }).to eq true
    end

    it 'Se puede buscar instancias persistidas por valores de atributos' do
      @estudiante.edad = 35
      @estudiante.save!
      @profesor.edad = 35
      @profesor.save!

      expect(Profesor.find_by_edad(35)).to eq([@profesor]) end

  end

  describe 'Relaciones entre objetos' do
    after(:context) do
      Estudiante.table.clear
      Grade.table.clear
      Ayudante.table.clear
      Profesor.table.clear
    end
    it 'Al persistirse un objeto se persisten todos los compuestos ' do
      grade1 = Grade.new
      grade1.value = 4
      @estudiante.grade = grade1
      @estudiante.save!
      grades = Grade.all_instances
      expect(grades).to eq [grade1]
    end

    it 'Cuando se recupera el objeto, todos los objetos compuestos se recuperan de sus tablas' do
      @estudiante.grade = Grade.new
      @estudiante.grade.value = 4
      @estudiante.save!

      grade = @estudiante.grade
      grade.value = 5
      grade.save!

      gradeEstudiante = @estudiante.refresh!.grade
      expect(gradeEstudiante.value).to eq 5
    end

    it 'Se permiten atributos has_many' do
      expect(@estudiante.historial).to eq []
    end

    it 'Se salvan los objetos y sus atributos persistibles has_many' do
      grade1 = Grade.new
      grade1.value = 7
      grade2 = Grade.new
      grade2.value = 9

      @estudiante.historial.push(grade1)
      @estudiante.historial.push(grade2)
      @estudiante.save!

      estudiantePersistido = @estudiante.refresh!
      expect([grade1, grade2].all? {|e| Grade.all_instances.include? e }).to eq true
      expect(estudiantePersistido.historial).to eq [grade1, grade2]
    end

    it 'Los módulos no tienen tablas, y las clases tienen tablas con sus atributos y los de su padre' do
      Profesor.table.clear
      Ayudante.table.clear
      
      profesor = Profesor.new
      profesor.full_name = "Bruno Diaz"
      profesor.materia = "TADP"
      profesor.edad = 42
      profesor.save!

      ayudante1 = Ayudante.new
      ayudante1.materia = "TADP"
      ayudante1.full_name = "Ricardo Tapia"
      ayudante1.edad = 25
      ayudante1.type = "Aprendiz"
      ayudante1.save!

      ayudante2 = Ayudante.new
      ayudante2.materia = "ADS"
      ayudante2.full_name = "Damian Diaz"
      ayudante2.edad = 19
      ayudante2.type = "Aprendiz"
      ayudante2.save!

      expect([profesor, ayudante1, ayudante2].all? {|e| Person.all_instances.include? e }).to eq true
      expect([ayudante1, ayudante2].all? {|e| Ayudante.all_instances.include? e }).to eq true
      expect([profesor, ayudante1].all? {|e| Profesor.find_by_materia("TADP").include? e }).to eq true
    end

  end

  describe 'Validaciones y defaults' do
    it 'Un objeto no se puede persistir con un atributo (primitivo) de tipo distinto al definido en la clase' do
      @estudiante.full_name = 3
      expect{@estudiante.save!}.to raise_error(PersistibleInvalido)
    end

    it 'Un objeto no se puede persistir con un atributo (complejo) de tipo distinto al definido en la clase' do
      @estudiante.grade = "Nueve"
      expect{@estudiante.save!}.to raise_error(PersistibleInvalido)
    end

    describe 'Validadores especificos' do
      before(:context) do
        class EstudianteParaValidadores
          include Person
          has_one Numeric, named: :edad, default: 18, no_blank: true
          has_one Grade, named: :grade, no_blank: true
          has_one Numeric, named: :diaCumple, validate: proc { self % 1 == 0 }
          has_many String, named: :objetos, no_blank: true
        end
      end
    it 'El validador no-blank funciona tanto para atributos primitivos como complejos'  do

      class MiEstudianteNoBlank
        include Persistible
        has_one Numeric, named: :edad, no_blank: true
        has_many String, named: :objetos, no_blank: true
      end

      estudiante = MiEstudianteNoBlank.new
      expect{estudiante.save!}.to raise_error(PersistibleInvalido)
      estudiante.objetos = [""]
      expect{estudiante.save!}.to raise_error(PersistibleInvalido)
      estudiante.objetos = ["Celular"]
      estudiante.edad = nil
      expect{estudiante.save!}.to raise_error(PersistibleInvalido)
      estudiante.edad = 18
      estudiante.save!
        
    end

      it 'Los validadores from y to restringen el rango de valores que puede tomar el atributo' do

        class MiEstudianteFromTo
          include Persistible
          has_one Numeric, named: :nota, from: 1, to: 10
        end


        estudiante = MiEstudianteFromTo.new
        estudiante.nota = 11
        expect{estudiante.save!}.to raise_error(PersistibleInvalido)
        estudiante.nota = 0
        expect{estudiante.save!}.to raise_error(PersistibleInvalido)
        estudiante.nota = 2
        estudiante.save!
      end
      
      it 'Se puede validar una condicion especifica' do
      class MiEstudianteValidate
        include Persistible
        has_one Numeric, named: :dia_cumple, validate: proc { self % 1 == 0 }
      end

      estudiante = MiEstudianteValidate.new
      estudiante.dia_cumple = 3.5
      expect{estudiante.save!}.to raise_error(PersistibleInvalido)
      estudiante.dia_cumple = 4
      estudiante.save!
      end
    end

  it 'Los atributos pueden tener valores default de instanciaciacion' do

    class MiEstudianteDefault
      include Persistible
      has_one Numeric, named: :edad, default: 18
      has_one String, named: :nombre, default: "Juan Perez"
      has_many String, named: :objetos, default: ["Celular","Billetera","Sube"]
    end

    estudiante = MiEstudianteDefault.new
    expect(estudiante.nombre).to eq "Juan Perez"

    estudiante.nombre = "Felicia"
    estudiante.objetos = []
    estudiante.save!

    expect(estudiante.nombre).to eq "Felicia"
    expect(["Celular","Billetera","Sube"].all? {|e| estudiante.objetos.include? e }).to eq true
    expect(estudiante.edad).to eq 18
  end


  end

  describe 'Test Integral' do
    before(:context) do
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
        has_one Numeric, named: :value
      end

      module Person
        include LivingBeing  # persistible.included(self)
        has_many String, named: :objetos
        has_one String, named: :full_name, default: "Juan Perez"
      end

      class Student
        include Person # person.included(self)
        has_one Grade, named: :grade
        has_many Grade, named: :historial, no_blank: true
      end
      class AsesinoSerial < Student
        has_many Alien, named: :personalidades
      end
      class AssistantProfessor < Student
        has_one String, named: :type
      end

      @grade1= Grade.new
      @grade1.value = 6

      @alien1 = Alien.new
      @alien1.especie = "Extraterrestre"
      @alien1.planeta = "Saturno"
      @alien1.ojos = ["verde","azul"]
      @alien1.validate!

      @alien2 = Alien.new
      @alien2.especie = "Extraterrestre"
      @alien2.planeta = "Jupiter"
      @alien2.ojos = ["marron","turquesa"]
      @alien2.save!

      @profesor = AssistantProfessor.new
      @profesor.especie = "Humano"
      @profesor.type = "Capo"
      @profesor.objetos = ["cuchara","cafe"]
      @profesor.historial= [@grade1,@grade1]
      @profesor.save!

      @estudiante = Student.new
      @estudiante.full_name = "Pedro Pascal"
      @estudiante.especie = "Humano"
      @estudiante.grade = Grade.new
      @estudiante.grade.value = 5
      @estudiante.objetos = ["lapiz","cuaderno"]
      @estudiante.historial= [@grade1]
      @estudiante.validate!
      @estudiante.save!

      @asesino = AsesinoSerial.new
      @asesino.full_name= "Freddy Krueger"
      @asesino.especie = "Humano"
      @asesino.personalidades = [@alien1,@alien2]
      @asesino.historial= [@grade1]
      @asesino.save!

    end
    after(:context) do
      @grade1.class.table.clear
      @alien1.class.table.clear
      @alien2.class.table.clear
      @profesor.class.table.clear
      @estudiante.class.table.clear
      @asesino.class.table.clear
    end
    it 'Las personas se recuperan correctamente' do
      expect([@profesor,@estudiante,@asesino].all? {|e| Person.all_instances.include? e }).to eq true
    end
    it 'Los seres vivos se recuperan correctamente' do
      expect([@alien1,@alien2,@profesor,@estudiante,@asesino].all? {|e| LivingBeing.all_instances.include? e }).to eq true
    end
  end
end
