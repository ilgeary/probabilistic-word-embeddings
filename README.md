# word-embedding
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
    initModel.jl
    coreFeatDefs.jl
    featspec.csv
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

The tiers are used for compactly encoding the UdepCC data while still allowing random access to it at the document level for both memorization and generalization learning purposes. The first tier assigns a byte-sized integer to the most frequent sets of features+form+lexeme which occur 20,000 times or more in the given chunk. The second tier similarly assigns two-byte+ integers for the next most frequent feature tuples (excluding form and lexeme). The third tier excludes form, lexeme, and head offset. 

The tier definitions are in the binTierDefs.jl file.

Each chunk of DepCC data is first binarized by mapping strings and feature combinations to integers (taking advantage of the Zipf-ian power law distribution of words/features).  The feature combinations are grouped into tiers by frequency, and by subsets of feature combinations. The binarization is like compression, except that it takes half the size of compression, and individual documents are still randomly accessible.  

Indexes, I am also collecting counts of features and feature combinations.  This is really memory-intensive because ultimately there is an infinite set of potential features, and so I can only keep the ones that are most frequent and/or have the highest Mutual Information.
