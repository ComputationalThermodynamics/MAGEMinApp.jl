// tentative template for solution phase model dictionary-lie structure (can be json or others)
phaseName {
    phase_info {
        full_name {"foolite"},
        identifier {"foo_ig_24"},
        reference {"Green et al., 2024"},

        formula { Maybe E-m formula and Mixing sites here too? },
        history { Track and changes maybe too? }
    },
    compositional_variable {
        name {["a","b","c"]},
        lower_bound {[0,0,-1]},
        upper_bound {[1,1,1]}
    },
    label {
        full_name {["foolite","doolite"]},
        name {["foo1","foo2"]},
        condition {[" a - 0.2", ""]}
    },
    site_fraction {
        names {["aM1","bM2","cT"]},
        definition {[" a + b -c ","c*2 + a", "a + b"]}
    },
    proportion {
        names {["em1","em2","em3"]},
        definition {[" a + b -c ","c*2 + a", "a + b"]}
    },
    ideal_mixing {
        name {["em1","em3","em3"]},
        definition {[" aM1^2 "," bM2^2", "cT^3"]}
    },
    non_ideality {
        W { name {["W(em1,em2)","W(em1,em3)","W(em3,em2)"]},
            definition {[12,0,24]}},
        v { name {["em1","em3","em3"]},
            definition {[1,1.1,1]} 
        }
    },
    make_endmember {
        name {["em1","em3","em3"]},
        definition {["em1","em2","em1 + em2 - em3 - 25"]}
    }

    // FOR MAGEMIN
    pseudocompound {
        step { 0.24 },                                          // step for the discretization (this is usually refined )
        shift { 1e-4 },                                         // shift from lower bound
        lower_bound {[0,0,-0.5]},
        upper_bound {[1,1,1]},
    },
    compositional_variable_as_proportion {                      // I need this for the initial stage to convert pure endmember as compositional variables
                                                                // but maybe you have a better way to retrieve the cv of the endmembers?
        name {["a","b","c"]},
        definition {["em1 + em2","em1/2 - em3","em3"]}
    },
    reduced_system {                                            // does not work for all components but I manage to deactivate Cr2O3, TiO2, MnO and O that way
        name {["TiO2","Cr2O3"]},
        compositional_variable_restriction {["a","c"]},         // it means that I will set the bounds of the compositional variable to 0.0
        endmember_restriction {["em1","em3"]}                   // it means that I sent the endmember fraction to 0.0, and the value of em_idm() to 0.0
    },
    anti_ordering {                                             // this is a new strategy where I add the anti-ordering instance of the phase
        active { 1 }                                            // or 0 if inactive
        composittional_variable {[2,3]}                         // which are the ordering variables? 
    }
}