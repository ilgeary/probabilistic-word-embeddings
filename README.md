# word-embeddings
Contextual word embeddings

To run, at Julia prompt type:
1> import Pkg; Pkg.add(["Unicode", "BSON", "JSON", "AWS", "AWSS3", "FilePathsBase"])
2 (optional)> prepBinaryScheme()  
3 (optional)> binarizeDepccFile()  
4>  ...

AWS CLI tools must be installed to run step #2.  
(See https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

[Overview slides] 
(https://docs.google.com/presentation/d/144nVjzHucXdoaF1xWXq4R0F4ZYCVm6kM6YxId4p_gII/edit?usp=sharing)


[Progress Tracking and Notes]
(https://docs.google.com/document/d/1--LTMxKQGxuMZzj1N_8XxkBABvB0O-MnVmZx17fFKFs/edit?usp=sharing)


Rough order of execution/reference of source files:

    udepToken.jl
    modelspec.jl
    initModel.jl  initModel_v-1.0.jl
    coreFeatDefs.jl; featspec.csv
    setupUdepccVals.jl
    extractWiktionaryVocab.jl
    udepConstructors.jl
    binTierDefs.jl	
    setupBinarization.jl
    accessoryFeatDefs.jl
    writeBinUdepcc.jl
    binarizeUdepcc.jl
		
Obsolete, but present for referential purposes as it contains exhausitive lists of core feature values:

    fvalListsAndDicts.jl

The tiers are used for compactly encoding the UdepCC data while still allowing access to it for both memorization and generalization learning purposes. The first tier assigns a byte-sized integer to the most frequent sets of features+form+lexeme which occur 20,000 times or more in the given chunk. The second tier similarly assigns two-byte+ integers for the next most frequent feature tuples (excluding form and lexeme). The third tier excludes form, lexeme, and head offset. 

The tier definitions are in the binTierDefs.jl file.
