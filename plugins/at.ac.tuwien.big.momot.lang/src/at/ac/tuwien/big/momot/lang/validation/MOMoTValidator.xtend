/*
 * generated by Xtext
 */
package at.ac.tuwien.big.momot.lang.validation

import at.ac.tuwien.big.moea.search.algorithm.provider.IRegisteredAlgorithm
import at.ac.tuwien.big.moea.util.CastUtil
import at.ac.tuwien.big.momot.ModuleManager
import at.ac.tuwien.big.momot.lang.momot.AlgorithmList
import at.ac.tuwien.big.momot.lang.momot.AlgorithmReferences
import at.ac.tuwien.big.momot.lang.momot.AlgorithmSpecification
import at.ac.tuwien.big.momot.lang.momot.ExperimentOrchestration
import at.ac.tuwien.big.momot.lang.momot.FitnessDimensionOCL
import at.ac.tuwien.big.momot.lang.momot.MOMoTSearch
import at.ac.tuwien.big.momot.lang.momot.ModuleOrchestration
import at.ac.tuwien.big.momot.lang.momot.MomotPackage
import at.ac.tuwien.big.momot.lang.momot.ObjectivesCommand
import at.ac.tuwien.big.momot.lang.momot.SaveAnalysisCommand
import at.ac.tuwien.big.momot.lang.momot.SearchOrchestration
import at.ac.tuwien.big.momot.lang.momot.SolutionsCommand
import at.ac.tuwien.big.momot.problem.solution.variable.UnitApplicationVariable
import at.ac.tuwien.big.momot.search.engine.MomotEngine
import com.google.inject.Inject
import java.util.ArrayList
import java.util.HashSet
import java.util.List
import java.util.Map
import org.eclipse.core.resources.IFile
import org.eclipse.core.resources.ResourcesPlugin
import org.eclipse.core.runtime.Path
import org.eclipse.emf.common.util.WrappedException
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.xmi.PackageNotFoundException
import org.eclipse.emf.henshin.model.resource.HenshinResourceSet
import org.eclipse.ocl.ParserException
import org.eclipse.ocl.ecore.OCL
import org.eclipse.xtext.validation.Check
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.XbasePackage
import org.eclipse.xtext.xbase.controlflow.EarlyExitInterpreter
import org.eclipse.xtext.xtype.XImportDeclaration
import org.moeaframework.algorithm.NSGAII
import org.eclipse.emf.common.util.URI
import java.io.File
import at.ac.tuwien.big.momot.lang.preference.MOMoTPreferences

/**
 * This class contains custom validation rules. 
 *
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#validation
 */
class MOMoTValidator extends AbstractMOMoTValidator {
   
   
   static final val wsRoot = ResourcesPlugin.workspace.root
   
   @Inject EarlyExitInterpreter interpreter
   
   var ModuleManager manager;
   val engine = new MomotEngine
      
   static def project(EObject it) {
      val path = new Path(eResource?.URI.toPlatformString(true))
      wsRoot?.getFile(path)?.project
   }
   
   static def projectMember(EObject it, String relativePath) {
      project?.findMember(relativePath)
   }
   
   static def projectFileExists(EObject it, String relativePath) {
      val member = projectMember(relativePath)
      if(member == null)
         return false
      return member instanceof IFile && member.exists
   }
   
   override protected addImportUnusedIssues(Map<String, List<XImportDeclaration>> imports) {
       // super.addImportUnusedIssues(imports) // comment to ignore 'import not used'
   }
   
   def <T> T interpret(XExpression expression, Class<T> clazz) {
      CastUtil.asClass(interpret(expression), clazz)
   }
   
   def interpret(XExpression expression) {
      if(expression == null)
         return null
         
      try {
         interpreter.evaluate(expression)
      } catch(Exception e) {
         null // fail silently: e.printStackTrace
      }
   }
   
   def getInputGraph(MOMoTSearch it) {
      if(searchOrchestration == null)
         return null;
      if(searchOrchestration.model != null) {
         val path = searchOrchestration.model.path.interpret(typeof(String))
         if(path != null) {
            val member = searchOrchestration?.model.projectMember(path)
            if(!(member instanceof IFile && member.exists))
               error("Model file '" + path + "' does not exist.", 
                  it, 
                  MomotPackage.Literals.SEARCH_ORCHESTRATION__MODEL
               )
            else {
               val manager = getManager
               try {
                  return manager.loadGraph(member.fullPath.toString)
               } catch(PackageNotFoundException e) {
                  return null
               } catch(WrappedException ex) {
                  return null
               }
            }
         }
      }
      return null
   }
   
   def getManager(MOMoTSearch it) {
      manager = new ModuleManager
      val modules = searchOrchestration?.moduleOrchestration?.modules
      if(modules == null)
         return manager

      for(module : modules.elements) {
         var path = module.interpret(typeof(String))
         if(path != null) {
         	var uri = URI.createURI(new File(path).path.toString, true).toString
            val member = it.projectMember(uri)
            if(member instanceof IFile && member.exists)
               try {
	               	manager.addModule(uri)
               	} catch(Exception e) {
//               		error("File '" + member.fullPath.toString + "' not found.",
//               			searchOrchestration.moduleOrchestration,
//               			MomotPackage.Literals.MODULE_ORCHESTRATION__MODULES)
               	}
         }
      }
      return manager
   }
   
   /**
    * Search Checks
    ******************************************/
   
   @Check
   def checkUnitApplicability(MOMoTSearch it) {
   	if(!MOMoTPreferences.evaluationUnitApplicability)
   		return;
   		
      val manager = getManager
      val graph = getInputGraph
      if(manager == null || graph == null || searchOrchestration.model?.adaptation != null)
         return;
         
      var executable = false
      var error = false
      for(unit : manager.units) {
         val application = new UnitApplicationVariable(engine, graph, unit, null)
         try {
            executable = application.execute
            if(executable)
               return;
         } catch(Exception e) {
            error = true
         }
      }
      if(!executable && !error)
         error("None of the provided transformations can be applied.",
            it.searchOrchestration,
            MomotPackage.Literals.SEARCH_ORCHESTRATION__MODULE_ORCHESTRATION
         )
   }
   
   @Check
   def checkAlgorithmRuns(ExperimentOrchestration it) {
   	if(!MOMoTPreferences.evaluationAlgorithmRuns)
   		return;
   		
      val runs = nrRuns.interpret(typeof(Integer))
      if(runs == null)
         return;
         
      if(runs < 30)
         warning("Since we are using meta-heuristics, at least 30 runs should be given to draw statistically valid conclusions.",
            it,
            MomotPackage.Literals.EXPERIMENT_ORCHESTRATION__NR_RUNS
         )
   }
   
   @Check
   def checkNumberOfIterations(ExperimentOrchestration it) {
   	if(!MOMoTPreferences.evaluationPopulationSize)
   		return;
      val maxEval = maxEvaluations.interpret(typeof(Integer))
      val population = populationSize.interpret(typeof(Integer))
      if(maxEval == null || population == null)
         return;
      
      val iterations = maxEval / population
      if(iterations < 10)
         warning("Running only " + iterations + " iterations (maxEvaluations / populationSize) may not be sufficient to " +
            "converge to a good search area, try at least 10 iterations, i.e., " + 10 * population + " maxEvaluations.",
            it,
            MomotPackage.Literals.EXPERIMENT_ORCHESTRATION__MAX_EVALUATIONS
         )
   }
   
   def getAlgorithmType(AlgorithmSpecification it) {
      var type = call.actualType
      if(type.isAssignableFrom(IRegisteredAlgorithm))
         type = type.typeArguments.get(0)
      return type   
   }

   def isNSGAII(AlgorithmSpecification it) {
      algorithmType.isSubtypeOf(typeof(NSGAII))
   }
   
   @Check
   def checkManyObjective(SearchOrchestration it) {
   	if(!MOMoTPreferences.evaluationManyObjectives)
   		return;
      val nrObjectives = fitnessFunction.objectives.size
      if(nrObjectives > 3) {
         for(algorithm : algorithms.specifications) {
            if(!algorithm.NSGAII)
               warning("Algorithm may not produce good results with more than 3 objectives.", 
                  algorithm, 
                  MomotPackage.Literals.ALGORITHM_SPECIFICATION__CALL
               )
         }
      }
   }
   
   @Check
   def checkObjectIdentity(MOMoTSearch it) {
   	if(!MOMoTPreferences.evaluationObjectIdentity)
   		return;
   		
      if(searchOrchestration.equalityHelper != null)
         return;

      val manager = getManager
      if(manager == null)
         return;
      for(parameter : manager.solutionParameters) {
         val type = parameter.type.instanceClass
         if(type.interface)
            return; // TODO: Implement to check for implementation of interfaces 
         if(parameter instanceof EObject) {
            try {
               val method = type.getMethod("equals", typeof(Object))
               if(method.declaringClass == typeof(Object))
                  warning("No equals method for '" + type.simpleName + "' found. Please provide one or implement an equality helper. Type: " + method.declaringClass,
                     it.searchOrchestration.moduleOrchestration,
                     MomotPackage.Literals.MODULE_ORCHESTRATION__PARAMETER_VALUES
                  )
            } catch(Exception e) {
               if(type == typeof(Object))
                  warning("No equals method for '" + type.simpleName + "' found. Please provide one or implement an equality helper. Exception: " + e.message,
                     it.searchOrchestration.moduleOrchestration,
                     MomotPackage.Literals.MODULE_ORCHESTRATION__PARAMETER_VALUES
                  )
            }
         }
      }
   }
   
   @Check
   def checkPopulationSize(ExperimentOrchestration it) {
   	if(!MOMoTPreferences.evaluationNrIterations)
   		return;
   		
      val population = populationSize.interpret(typeof(Integer))
      if(population == null)
         return;
      if(population <= 10) 
         warning("Specified Population Size is very small, please consider using a higher value.",
            it,
            MomotPackage.Literals.EXPERIMENT_ORCHESTRATION__POPULATION_SIZE
         )
   }
   
   @Check
   def checkSingleObjective(SearchOrchestration it) {
   	if(!MOMoTPreferences.evaluationSingleObjective)
   		return;
   		
      val nrObjectives = fitnessFunction.objectives.size
      if(nrObjectives == 1) {
         info("For single objective search, please consider using local search algorithms, such as HillClimbing or RandomDescent.",
            it,
            MomotPackage.Literals.SEARCH_ORCHESTRATION__ALGORITHMS
         )
      }
   }
   
   /**
    * Consistency Checks
    ******************************************/
   
   @Check
   def checkModuleFileExistence(ModuleOrchestration it) {
   	if(!MOMoTPreferences.evaluationModuleFileExistence)
   		return
      var index = 0
      for(module : modules.elements) {
         val path = module.interpret(typeof(String))
         if(path != null && !projectFileExists(path))
            error("Module file '" + path + "' does not exist.", 
               modules, 
               XbasePackage.Literals.XCOLLECTION_LITERAL__ELEMENTS, 
               index
            )
         index++      
      }      
   }
   
   @Check
   def checkDuplicateAlgorithmName(AlgorithmList it) {
   	if(!MOMoTPreferences.evaluationDuplicateAlgorithmName)
   		return;
      val names = new HashSet
      val duplicates = new ArrayList
      for(spec : specifications) {
         if(names.contains(spec.name))
            duplicates.add(spec)
         names.add(spec.name)
      }
      
      for(spec : duplicates)
         error("Algorithm with duplicate name '" + spec.name + "'.", 
            spec, 
            MomotPackage.Literals.ALGORITHM_SPECIFICATION__NAME
         )
   }
   
   @Check
   def checkDuplicateAlgorithmReference(AlgorithmReferences it) {
   		if(!MOMoTPreferences.evaluationDuplicateAlgorithmReference)
   		return;
   		
      val names = new HashSet
      val duplicates = new ArrayList
      for(spec : elements) {
         if(names.contains(spec.name))
            duplicates.add(spec)
         names.add(spec.name)
      }
      
      for(spec : duplicates)
         error("Algorithm with name '" + spec.name + "' specified multiple times.", 
            it, 
            MomotPackage.Literals.ALGORITHM_REFERENCES__ELEMENTS
         )
   }
   
   @Check
   def checkModelFileExistence(SearchOrchestration it) {
   	if(!MOMoTPreferences.evaluationModelFileExistence)
   		return;
      if(model != null) {
         val path = model.path.interpret(typeof(String))
         if(path != null) {
            if(!model.projectFileExists(path))
               error("Model file '" + path + "' does not exist.", 
                  it, 
                  MomotPackage.Literals.SEARCH_ORCHESTRATION__MODEL
               )
         }
      }
   }

   @Check
   def checkOCL(SearchOrchestration it) {
   	if(!MOMoTPreferences.evaluationOCL)
   		return;
      if(it != null && model != null && fitnessFunction != null) {
         val path = model.path.interpret(typeof(String))
         if(path != null) {
            val member = project?.findMember(path)
            if(!member.exists)
               return
            var EObject root
            try {
               for(objective : fitnessFunction.objectives) {
                  if(objective instanceof FitnessDimensionOCL) {
                     val ocl = OCL::newInstance
                     val oclObjective = objective as FitnessDimensionOCL
                     val helper = ocl.createOCLHelper
                     if(root == null) {
                        val set = new HenshinResourceSet
                        val resource = set.getResource(member.fullPath.toString)
                        root = resource.contents.get(0)
                     }
                     helper.context = root.eClass
                     var index = 0
                     try {
                        for(def : oclObjective.defExpressions) {
                           helper.defineAttribute(def.expression)
                           index++
                        }
                     } catch(ParserException e) {
                        error("OCL: " + e.localizedMessage, oclObjective, MomotPackage.Literals.FITNESS_DIMENSION_OCL__DEF_EXPRESSIONS, index)
                     }
                     
                     try {
                        val query = oclObjective.query.interpret(typeof(String))
                        helper.createQuery(query)
                     } catch(ParserException e) {
                        error("OCL: " + e.localizedMessage, oclObjective, MomotPackage.Literals.FITNESS_DIMENSION_OCL__QUERY)   
                     }
                  }
               }
            } catch(Exception e) {
               error("Error: " + e.localizedMessage, it, MomotPackage.Literals.SEARCH_ORCHESTRATION__MODEL)   
            }
         }
      }   
   }
   
   @Check
   def checkDuplicateParameterKeys(ModuleOrchestration it) {
   	if(!MOMoTPreferences.evaluationDuplicateParameterKeys)
   		return;
   		
      val names = new HashSet
      val duplicates = new ArrayList
      for(spec : parameterValues) {
         val name = spec.name.interpret(typeof(String))
         if(name != null) {
            if(names.contains(name))
               duplicates.add(spec)
            names.add(name)
         }
      }
      
      for(spec : duplicates)
         error("Set value for parameter '" + interpreter.evaluate(spec.name) as String + "' multiple times.", spec, MomotPackage.Literals.PARMETER_VALUE_SPECIFICATION__NAME)
   }
   
   @Check
   def checkTransformationOrchestration(MOMoTSearch it) {
   		
      if(it != null && searchOrchestration != null && searchOrchestration.moduleOrchestration != null) {
         val transOrchestration = searchOrchestration.moduleOrchestration
         val manager = getManager(it)
         
         if(transOrchestration.unitsToRemove != null && MOMoTPreferences.evaluationUnitExistence) {
            var index = 0
            for(unit : transOrchestration.unitsToRemove.elements) {
               val name = unit.interpret(typeof(String))
               if(manager.getUnit(name) == null)
                  error(
                     "Unit '" + name + "' does not exist in the specified modules.", 
                     transOrchestration.unitsToRemove, 
                     XbasePackage.Literals.XCOLLECTION_LITERAL__ELEMENTS, 
                     index
                  )
               index++
            }
         }
         
         if(transOrchestration.parameterValues != null && MOMoTPreferences.evaluationParameterExistence) {
            var index = 0
            val names = new HashSet
            val duplicates = new ArrayList
            for(spec : transOrchestration.parameterValues) {
               val name = spec.name.interpret(typeof(String))
               if(name != null) {
                  if(names.contains(name))
                     duplicates.add(spec)
                  names.add(name)
                  
                  if(manager.getParameter(name) == null)
                     error(
                        "Parameter '" + name + "' does not exist in the specified modules.", 
                        transOrchestration, 
                        MomotPackage.Literals.MODULE_ORCHESTRATION__PARAMETER_VALUES, 
                        index)
               }
               index++
            }
            
            for(spec : duplicates)
               error("Set value for parameter '" + interpreter.evaluate(spec.name) as String + "' multiple times.", 
                  spec, 
                  MomotPackage.Literals.PARMETER_VALUE_SPECIFICATION__NAME
               )
         }
         
         if(transOrchestration.nonSolutionParameters != null && MOMoTPreferences.evaluationParameterExistence) {
            var index = 0;
            for(p : transOrchestration.nonSolutionParameters.elements) {
               val name = p.interpret(typeof(String))
               if(manager.getParameter(name) == null)
                  error(
                  "Parameter '" + name + "' does not exist in the specified modules.", 
                     transOrchestration.nonSolutionParameters, 
                     XbasePackage.Literals.XCOLLECTION_LITERAL__ELEMENTS, 
                     index
                  )
               index++
            }
         }
      }
   }
   
   @Check
   def checkReferenceSetExistence(ExperimentOrchestration it) {
   	if(!MOMoTPreferences.evaluationReferenceSetExistence)
   		return;
      if(referenceSet != null) {
         val path = referenceSet.interpret(typeof(String))
         if(path != null) {
            if(!it.projectFileExists(path))
               error("ReferenceSet file '" + path + "' does not exist.", 
                  it, 
                  MomotPackage.Literals.EXPERIMENT_ORCHESTRATION__REFERENCE_SET
               )
         }
      }
   }
   
   @Check 
   def checkAnalysisFileOverriden(SaveAnalysisCommand it) {
   	if(!MOMoTPreferences.evaluationAnalysisFileOverriden)
   		return;
      if(it != null && file != null) {
         val path = file.interpret(typeof(String))
         if(path != null) {
            if(it.projectFileExists(path))
               info("Analysis file '" + path + "' will be overridden.", 
                  it, 
                  MomotPackage.Literals.SAVE_ANALYSIS_COMMAND__FILE
               )
         }
      }
   }
   
   @Check 
   def checkObjectivesFileOverriden(ObjectivesCommand it) {
   	if(!MOMoTPreferences.evaluationObjectivesFileOverriden)
   		return;
      if(it != null && file != null) {
         if(it.projectFileExists(file))
            info("Objective file '" + file + "' will be overridden.", 
               it, 
               MomotPackage.Literals.OBJECTIVES_COMMAND__FILE
            )
      }
   }
   
   @Check 
   def checkSolutionsFileOverriden(SolutionsCommand it) {
   	if(!MOMoTPreferences.evaluationSolutionsFileOverriden)
   		return;
      if(it != null && file != null) {
         if(it.projectFileExists(file))
            info("Objective file '" + file + "' will be overridden.", 
               it, 
               MomotPackage.Literals.SOLUTIONS_COMMAND__FILE
            )
      }
   }
   
}
