local TreePlotRuntimeOrchestrator = {}

function TreePlotRuntimeOrchestrator.configure(deps)
	deps.treePlotRuntimeService.configureRuntime({
		plotSetIdAttribute = deps.constants.PlotSetIdAttribute,
		plotSetSpawnName = deps.constants.PlotSetSpawnName,
		cleanupPlayerRuntime = deps.treeRuntimeManager.cleanupPlayerRuntime,
		setPlotSetId = deps.treeRuntimeManager.setPlotSetId,
		refreshAllAssignedPlots = deps.treePlotMaterializer.refreshAllAssignedPlots,
	})
end

return TreePlotRuntimeOrchestrator
