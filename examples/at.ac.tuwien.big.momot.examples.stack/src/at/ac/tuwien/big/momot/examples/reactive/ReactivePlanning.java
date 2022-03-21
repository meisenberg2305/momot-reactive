package at.ac.tuwien.big.momot.examples.reactive;

import at.ac.tuwien.big.momot.examples.stack.StackSearch;
import at.ac.tuwien.big.momot.examples.stack.StackSolutionWriter;
import at.ac.tuwien.big.momot.examples.stack.stack.StackPackage;
import at.ac.tuwien.big.momot.reactive.AbstractDisturber;
import at.ac.tuwien.big.momot.reactive.Executor;
import at.ac.tuwien.big.momot.reactive.IReactiveUtilities;
import at.ac.tuwien.big.momot.reactive.Printer;
import at.ac.tuwien.big.momot.reactive.ReactiveExperiment;
import at.ac.tuwien.big.momot.reactive.error.ErrorOccurence;
import at.ac.tuwien.big.momot.reactive.error.ErrorType;
import at.ac.tuwien.big.momot.reactive.planningstrategy.EvaluationReplanningStrategy;
import at.ac.tuwien.big.momot.reactive.planningstrategy.PlanningStrategy;
import at.ac.tuwien.big.momot.reactive.result.ReactiveResult;
import at.ac.tuwien.big.momot.search.fitness.IEGraphMultiDimensionalFitnessFunction;
import at.ac.tuwien.big.momot.util.MomotUtil;

import java.io.PrintStream;
import java.nio.file.Paths;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;

import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.xmi.impl.XMIResourceFactoryImpl;
import org.eclipse.emf.henshin.model.resource.HenshinResourceSet;

public class ReactivePlanning {
   final static boolean VERBOSE = true;

   /* EXPERIMENT CONFIGURATION */
   final static List<PlanningStrategy> PLANNING_STRATEGIES = Arrays.asList(new PlanningStrategy.PlanningStrategyBuilder(
         "NSGAII",
         new EvaluationReplanningStrategy.EvaluationReplanningStrategyBuilder("NSGAII").maxEvaluations(5000).build())
               .maxEvaluations(5000).build());
   // PlanningStrategy.create("NSGAII", 5000, EvaluationReplanningStrategy.create("NSGAII", 5000, false)));
   final static String INITIAL_MODEL = Paths.get("model", "model_five_stacks.xmi").toString();
   final static String HENSHIN_MODULE = Paths.get("model", "stack.henshin").toString();
   final static int MAX_SOLUTION_LENGTH = 10;
   final static int POPULATION_SIZE = 100;
   private static final int EXPERIMENT_RUNS = 5;
   final static String EVAL_OBJECTIVE = "Standard Deviation";

   /* DISTURBER CONFIGURATION */
   private static final ErrorType ERROR_TYPE = ErrorType.STRONG_ERROR;
   private static final ErrorOccurence ERROR_OCCURENCE = ErrorOccurence.FIRST_HALF;
   private static final float ERROR_PROBABILITY = 0.8f;
   private static final int MAX_DISTURBANCES_PER_RUN = 1;

   /* OUTPUTS */
   final static String OUT_BASE_PATH = Paths.get("output", "simulation").toString();
   final static PrintStream PS_OUT = System.out;
   // final static Printer PS_DIFF = new Printer(Paths.get(OUT_BASE_PATH, "summary.txt").toString());

   private static IEGraphMultiDimensionalFitnessFunction FITNESS_FUNCTION;

   public static void main(final String[] args) {
      StackPackage.eINSTANCE.eClass();
      final HenshinResourceSet hrs = new HenshinResourceSet();
      hrs.getResourceFactoryRegistry().getExtensionToFactoryMap().put("xmi", new XMIResourceFactoryImpl());
      final Resource initialModelRes = hrs.getResource(INITIAL_MODEL);
      Map<String, ReactiveResult> results = new HashMap<>();

      final AbstractDisturber disturber = new Disturber.DisturberBuilder().type(ERROR_TYPE).occurence(ERROR_OCCURENCE)
            .probability(ERROR_PROBABILITY).maxPlanLength(MAX_SOLUTION_LENGTH)
            .maxNrOfDisturbances(MAX_DISTURBANCES_PER_RUN).build();

      final Executor executor = new Executor(HENSHIN_MODULE);

      final IReactiveUtilities utils = new StackUtils();
      final Printer p = new Printer(PS_OUT, new StackSolutionWriter(utils.getFitnessFunction()));
      final ReactiveExperiment experiment = new ReactiveExperiment(MomotUtil.eGraphOf(initialModelRes, true),
            PLANNING_STRATEGIES, new StackSearch(), utils, disturber, executor, EVAL_OBJECTIVE, EXPERIMENT_RUNS,
            MAX_SOLUTION_LENGTH, POPULATION_SIZE, p, VERBOSE);

      results = experiment.runExperiment();

      p.header1("RESULTS");

      for(final Entry<String, ReactiveResult> e : results.entrySet()) {
         p.subheader(e.getKey());
         p.property(String.format("Final model objectives (%s)", EVAL_OBJECTIVE),
               Arrays.toString(e.getValue().getFinalObjectives().toArray()));
         p.property(String.format("Avg. final objective (%s)", EVAL_OBJECTIVE), Double.toString(Arrays
               .stream(e.getValue().getFinalObjectives().stream().mapToDouble(f -> f != null ? f : Float.NaN).toArray())
               .average().getAsDouble())).newline();

      }

   }
}