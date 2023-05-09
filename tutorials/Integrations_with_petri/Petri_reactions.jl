
using Petri

@net MyPetriNet begin
    @place p1
    @place p2
    @transition t1(p1, p2)
end

model = PetriNet()