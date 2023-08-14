describe Prueba do
  let(:person) { Person.new }

  describe 'Person' do
    it 'Person es una clase persistible' do
      expect(person.class.ancestor?(Persistible)).to be true
    end
  end
end