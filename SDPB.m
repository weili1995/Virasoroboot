(* ::Package:: *)

(*Setup*)
prec = 200;

(* A matrix with constant anti-diagonals given by the list bs *)
antiBandMatrix[bs_] := Module[
    {n = Ceiling[Length[bs]/2]},
    Reverse[Normal[
        SparseArray[
            Join[
                Table[Band[{i, 1}] -> bs[[n - i + 1]], {i, n}],
                Table[Band[{1, i}] -> bs[[n + i - 1]], {i, 2, n}]],
            {n, n}]]]];

(* DampedRational[c, {p1, p2, ...}, b, x] stands for c b^x / ((x-p1)(x-p2)...) *)
(* It satisfies the following identities *)

DampedRational[const_, poles_, base_, x + a_] := 
    DampedRational[base^a const, # - a & /@ poles, base, x];

DampedRational[const_, poles_, base_, a_ /; FreeQ[a, x]] := 
    const base^a/Product[a - p, {p, poles}];

DampedRational/:x DampedRational[const_, poles_ /; MemberQ[poles, 0], base_, x] :=
    DampedRational[const, DeleteCases[poles, 0], base, x];

DampedRational/:DampedRational[c1_,p1_,b1_,x] DampedRational[c2_,p2_,b2_,x] :=
    DampedRational[c1 c2, Join[p1, p2], b1 b2, x];

(* bilinearForm[f, m] = Integral[x^m f[x], {x, 0, Infinity}] *)
(* The special case when f[x] has no poles *)
bilinearForm[DampedRational[const_, {}, base_, x], m_] :=
    const Gamma[1+m] (-Log[base])^(-1-m);

(*memoizeGamma[a_,b_]:=memoizeGamma[a,b]=Gamma[a,b];*)

(* The case where f[x] has only single poles *)
(*bilinearForm[DampedRational[const_, poles_, base_, x], m_] := 
    const Sum[
        ((-poles[[i]])^m) ( base^poles[[i]]) Gamma[1 + m] memoizeGamma[-m, poles[[i]] Log[base]]/
        Product[poles[[i]] - p, {p, Delete[poles, i]}],
        {i, Length[poles]}];*)

(* The case where f[x] can have single or double poles *)
bilinearForm$original[DampedRational[c_, poles_, b_, x_], m_] := Module[
    {
        gatheredPoles = Gather[poles],
        quotientCoeffs = CoefficientList[PolynomialQuotient[x^m, Product[x-p, {p, poles}], x], x],
        integral, p, rest
    },
    integral[a_,1] := b^a Gamma[0, a Log[b]];
    integral[a_,2] := -1/a + b^a Gamma[0, a Log[b]] Log[b];
    c (Sum[
        p = gatheredPoles[[n,1]];
        rest = x^m / Product[x-q, {q, Join@@Delete[gatheredPoles, n]}];
        Switch[Length[gatheredPoles[[n]]],
               1, integral[p,1] rest /. x->p,
               2, integral[p,2] rest + integral[p,1] D[rest, x] /. x->p],
        {n, Length[gatheredPoles]}] + 
       Sum[
           quotientCoeffs[[n+1]] Gamma[1+n] (-Log[b])^(-1-n),
           {n, 0, Length[quotientCoeffs]-1}])];

IntegratePrefactorTerm[c_,p_,1,b_,m_]:=b^p c (-p)^m m! Gamma[-m,p Log[b]];
IntegratePrefactorTerm[c_,p_,1,b_,0]:=b^p c Gamma[0,p Log[b]];
IntegratePrefactorTerm[c_,p_,2,b_,m_]:=b^p c Gamma[m] (-Log[b])^-m Log[b] (b^-p+ExpIntegralE[m,p Log[b]] (-m-p Log[b]));
IntegratePrefactorTerm[c_,p_,2,b_,0]:=-(c/p)+b^p c Gamma[0,p Log[b]] Log[b];
IntegratePrefactorTerm[c_,p_,3,b_,m_]:=1/2 c (-2+m) Gamma[-2+m] (-Log[b])^(2-m) (-1-m-p Log[b]+b^p ExpIntegralE[-1+m,p Log[b]] ((-1+m) m-p Log[b] (-2 m-p Log[b])));
IntegratePrefactorTerm[c_,p_,3,b_,0]:=(c (1-p Log[b]+b^p p^2 Gamma[0,p Log[b]] Log[b]^2))/(2 p^2);
IntegratePrefactorTerm[c_,p_,3,b_,1]:=(c (-1-p Log[b]+b^p p ExpIntegralE[1,p Log[b]] Log[b] (2+p Log[b])))/(2 p);
IntegratePrefactorTerm[c_,p_,3,b_,2]:=1/2 c (-3-p Log[b]+b^p Gamma[0,p Log[b]] (2+p Log[b] (4+p Log[b])));
IntegratePrefactorTerm[c_,p_,n_,b_,m_]:=IntegratePrefactorTerm$Unknown[(c b^x)/(x-p)^n x^m];

ListTerms[expr_,head_]:=If[Head[expr]===head,List@@expr,{expr}];

bilinearForm[DampedRational[c_, poles_, b_, x], m_]:=Module[
{prefactor,rslt},
prefactor=1/Product[x - p, {p, poles}]//Apart//ListTerms[#,Plus]&;
(*  num/(A+B x)^n=(num/B^n)/(A/B+x)^n  *)

If[And@@(MatchQ[#,num_. (A_+B_. x)^n_.]&/@prefactor)=!=True,
Print["bilinearForm fail: unrecognizable prefactor form"];0];

rslt=prefactor/.num_. (A_+B_. x)^n_.:>IntegratePrefactorTerm[(c num)/B^n,-(A/B),-n,b,m];

(*Print[DampedRational[c, poles, b, x]," m=",m," rslt=",rslt];*)

rslt=Plus@@rslt;

If[NumberQ[rslt],
Return[rslt],
Print["bilinearForm fail: unsupported pole structure : ",rslt];Return[0];
];
];

(* orthogonalPolynomials[f, n] is a set of polynomials with degree 0
through n which are orthogonal with respect to the measure f[x] dx *)
orthogonalPolynomials[const_ /; FreeQ[const, x], 0] := {1/Sqrt[const]};

orthogonalPolynomials[const_ /; FreeQ[const, x], degree_] := 
    error["can't get orthogonal polynomials of nonzero degree for constant measure"];

orthogonalPolynomials[DampedRational[const_, poles_, base_, x], degree_] :=(*(Inverse1[
        CholeskyDecomposition[
            antiBandMatrix[
                Table[bilinearForm[DampedRational[const, Select[poles, # < 0&], base, x], m],
                      {m, 0, 2 degree}]]]]//Print;1)*)Table[x^m, {m, 0, degree}] . Inverse[
        CholeskyDecomposition[
            antiBandMatrix[
                Table[bilinearForm[DampedRational[const, Select[poles, # < 0&], base, x], m],
                      {m, 0, 2 degree}]]]];

(* Preparing SDP for Export *)
rhoCrossing = SetPrecision[3-2 Sqrt[2], prec];

rescaledLaguerreSamplePoints[n_] := Table[
    SetPrecision[\[Pi]^2 (-1+4k)^2/(-64n Log[rhoCrossing]), prec],
    {k,0,n-1}];

maxIndexBy[l_,f_] := SortBy[
    Transpose[{l,Range[Length[l]]}],
    -f[First[#]]&][[1,2]];

(* finds v' such that a . v = First[v'] + a' . Rest[v'] when normalization . a == 1, where a' is a vector of length one less than a *)
reshuffleWithNormalization[normalization_, v_] := Module[
    {j = maxIndexBy[normalization, Abs], const},
    const = v[[j]]/normalization[[j]];
    Prepend[Delete[v - normalization*const, j], const]];

(* XML Exporting *)
nf[x_Integer] := x;
nf[x_] := NumberForm[SetPrecision[x,prec],prec,ExponentFunction->(Null&)];

safeCoefficientList[p_, x_] := Module[
    {coeffs = CoefficientList[p, x]},
    If[Length[coeffs] > 0, coeffs, {0}]];

WriteBootstrapSDP[file_, SDP[objective_, normalization_, positiveMatricesWithPrefactors_]] := Module[
    {
        stream = OpenWrite[file],
        node, real, int, vector, polynomial,
        polynomialVector, polynomialVectorMatrix,
        affineObjective, polynomialVectorMatrices
    },

    (* write a single XML node to file.  children is a routine that writes child nodes when run. *)
    node[name_, children_] := (
        WriteString[stream, "<", name, ">"];
        children[];
        WriteString[stream, "</", name, ">\n"];
    );

    real[r_][] := WriteString[stream, nf[r]];
    int[i_][] := WriteString[stream, i];
    vector[v_][] := Do[node["elt", real[c]], {c, v}];
    polynomial[p_][] := Do[node["coeff", real[c]], {c, safeCoefficientList[p,x]}];
    polynomialVector[v_][] := Do[node["polynomial", polynomial[p]], {p, v}];

    polynomialVectorMatrix[PositiveMatrixWithPrefactor[prefactor_, m_]][] := Module[
        {degree = Max[Exponent[m, x]], samplePoints, sampleScalings, bilinearBasis},

        samplePoints   = rescaledLaguerreSamplePoints[degree + 1];
        sampleScalings = Table[prefactor /. x -> a, {a, samplePoints}];
        bilinearBasis  = orthogonalPolynomials[prefactor, Floor[degree/2]];
        node["rows", int[Length[m]]];
        node["cols", int[Length[First[m]]]];
        node["elements", Function[
            {},
            Do[node[
                "polynomialVector",
                polynomialVector[reshuffleWithNormalization[normalization,pv]]],
               {row, m}, {pv, row}]]];
        node["samplePoints", vector[samplePoints]];
        node["sampleScalings", vector[sampleScalings]];
        node["bilinearBasis", polynomialVector[bilinearBasis]];
    ];

    node["sdp", Function[
        {},
        node["objective", vector[reshuffleWithNormalization[normalization, objective]]];
        node["polynomialVectorMatrices", Function[
            {},
            Do[node["polynomialVectorMatrix", polynomialVectorMatrix[pvm]], {pvm, positiveMatricesWithPrefactors}];
        ]];
    ]];                                          

    Close[stream];
];
