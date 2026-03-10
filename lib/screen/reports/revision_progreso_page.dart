import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_routes.dart';
import '../../models/equipo.dart';
import '../../providers/equipo_provider.dart';
import '../../providers/revision_provider.dart';
import '../../models/equipo_revisado.dart';
import '../scanner_screen.dart';

class RevisionProgresoPage extends StatefulWidget {
  const RevisionProgresoPage({super.key});

  @override
  State<RevisionProgresoPage> createState() => _RevisionProgresoPageState();
}

class _RevisionProgresoPageState extends State<RevisionProgresoPage> {
  // final TextEditingController _manualController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Verificar que haya una revisión activa
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final revisionProvider = context.read<RevisionProvider>();
      if (!revisionProvider.hayRevisionActiva) {
        _mostrarErrorYVolver('No hay una revisión activa');
      }
    });
  }

  void _mostrarErrorYVolver(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) AppRoutes.goBack(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final revisionProvider = context.watch<RevisionProvider>();
    final revisionActual = revisionProvider.revisionActual;
    final equiposRevisados = revisionProvider.equiposRevisados;

    if (revisionActual == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Cargando revisión...'),
            ],
          ),
        ),
      );
    }

    final primaryColor = const Color(0xFF135bec);
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = 480.0;
    final padding = screenWidth > maxWidth ? (screenWidth - maxWidth) / 2 : 0.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFf6f6f8),
        shape: Border(bottom: BorderSide(color: const Color(0xFFe2e8f0))),
        leading: Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () {
              _confirmarSalida();
            },
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              shape: const CircleBorder(),
            ),
            icon: Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 24),
          ),
        ),
        centerTitle: true,
        title: Text(
          'Revisión en Progreso',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.015,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _mostrarOpciones,
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(48, 48),
            ),
            icon: Icon(Icons.more_vert, color: Colors.black, size: 24),
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFf6f6f8),
        child: SafeArea(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: padding),
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              children: [
                // Contenido principal
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Department Card
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFe2e8f0),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Departamento en Revisión',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748b),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFf1f5f9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    child: Text(
                                      revisionActual.departamentoNombre,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Progress Indicator
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFe2e8f0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Progreso',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                    Text(
                                      '${revisionProvider.equiposEscaneados}/${revisionProvider.totalEquipos}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value:
                                        revisionProvider.porcentajeProgreso /
                                        100,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      primaryColor,
                                    ),
                                    minHeight: 8,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildStat(
                                      'Correctos',
                                      equiposRevisados
                                          .where((e) => e.esEquipoCorrecto)
                                          .length
                                          .toString(),
                                      Colors.green,
                                    ),
                                    _buildStat(
                                      'Sobrantes',
                                      equiposRevisados
                                          .where((e) => e.esEquipoSobrante)
                                          .length
                                          .toString(),
                                      Colors.orange,
                                    ),
                                    _buildStat(
                                      'Faltantes',
                                      revisionProvider.equiposFaltantes
                                          .toString(),
                                      Colors.red,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Inventory List Header
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Equipos Escaneados (${equiposRevisados.length})',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'EN VIVO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // List Items
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: equiposRevisados.isEmpty
                              ? Container(
                                  width: maxWidth,
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFe2e8f0),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.qr_code_scanner,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Escanea el primer equipo',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  children: equiposRevisados
                                      .map(
                                        (equipo) =>
                                            _buildActivoItem(equipo: equipo),
                                      )
                                      .toList(),
                                ),
                        ),

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // Floating Action Buttons
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Botón Manual
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                heroTag: null,
                onPressed: _mostrarDialogoManual,
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const StadiumBorder(),
                icon: const Icon(Icons.edit),
                label: const Text(
                  'Manual',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // Botón Escanear QR
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                heroTag: null,
                onPressed: _abrirScanner,
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const StadiumBorder(),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text(
                  'Escanear QR',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      // Sticky Bottom Bar
      bottomSheet: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFf6f6f8),
          border: Border(top: BorderSide(color: const Color(0xFFe2e8f0))),
        ),
        child: SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            margin: EdgeInsets.symmetric(horizontal: padding),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botón Finalizar
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton.icon(
                    onPressed: _finalizarRevision,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      shadowColor: primaryColor.withValues(alpha: 0.2),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    icon: const Icon(Icons.description),
                    label: const Text('Finalizar y Generar Reporte'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String valor, Color color) {
    return Column(
      children: [
        Text(
          valor,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildActivoItem({required EquipoRevisado equipo}) {
    final tieneError = equipo.esEquipoSobrante;
    final esCorrecto = equipo.esEquipoCorrecto;

    Color colorEstado;
    IconData iconoEstado;
    String mensajeEstado;

    if (esCorrecto) {
      colorEstado = Colors.green;
      iconoEstado = Icons.check_circle;
      mensajeEstado = 'Correcto';
    } else if (equipo.esEquipoSobrante) {
      colorEstado = Colors.orange;
      iconoEstado = Icons.warning;
      mensajeEstado = 'Equipo de otro departamento';
    } else {
      colorEstado = Colors.red;
      iconoEstado = Icons.error;
      mensajeEstado = 'No encontrado';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tieneError
              ? colorEstado.withValues(alpha: 0.3)
              : const Color(0xFFe2e8f0),
        ),
      ),
      child: Stack(
        children: [
          if (tieneError)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: colorEstado,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icono principal
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorEstado.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    equipo.esEquipoSobrante ? Icons.warning : Icons.computer,
                    color: colorEstado,
                  ),
                ),
                const SizedBox(width: 16),

                // Información
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        equipo.nombreEquipo,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mensajeEstado,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colorEstado,
                        ),
                      ),
                      if (equipo.observaciones != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            equipo.observaciones!,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Icono de estado
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colorEstado.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconoEstado, color: colorEstado, size: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _abrirScanner() async {
    if (!mounted) return;

    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ScannerScreen(modoRevision: true),
      ),
    );

    if (resultado == true && mounted) {
      // Escaneo exitoso, ya se actualizó el provider
    }
  }

  void _mostrarDialogoManual() {
    if (!mounted) return;

    // ✅ Guardar referencia al contexto de la pantalla principal
    final scaffoldContext = context;

    final TextEditingController searchController = TextEditingController();
    List<Equipo> resultadosBusqueda = [];
    bool buscando = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        final revisionProvider = Provider.of<RevisionProvider>(
          dialogContext,
          listen: false,
        );
        final equipoProvider = Provider.of<EquipoProvider>(
          dialogContext,
          listen: false,
        );

        final todosLosEquipos = equipoProvider.equipos;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Buscar Equipo'),
              content: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Campo de búsqueda
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, serie o código QR...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  searchController.clear();
                                  setState(() {
                                    resultadosBusqueda = [];
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          buscando = true;
                        });

                        // final escaneadosIds = revisionProvider.equiposRevisados
                        //     .map((e) => e.equipoId)
                        //     .toSet();

                        final resultados = todosLosEquipos
                            .where(
                              (equipo) =>
                                  (equipo.nombre.toLowerCase().contains(
                                    value.toLowerCase(),
                                  ) ||
                                  equipo.numeroSerie.toLowerCase().contains(
                                    value.toLowerCase(),
                                  ) ||
                                  equipo.codigoQR.toLowerCase().contains(
                                    value.toLowerCase(),
                                  )),
                            )
                            .toList();

                        setState(() {
                          resultadosBusqueda = resultados;
                          buscando = false;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // Resultados
                    Expanded(
                      child: buscando
                          ? const Center(child: CircularProgressIndicator())
                          : resultadosBusqueda.isEmpty &&
                                searchController.text.isNotEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No se encontraron resultados',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(dialogContext);
                                      _registrarPorCodigoManual(
                                        searchController.text,
                                      );
                                    },
                                    icon: const Icon(Icons.qr_code),
                                    label: const Text(
                                      'Registrar como código QR',
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : resultadosBusqueda.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Escribe para buscar equipos',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: resultadosBusqueda.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(),
                              itemBuilder: (context, index) {
                                final equipo = resultadosBusqueda[index];
                                final yaEscaneado = revisionProvider
                                    .equiposRevisados
                                    .any((e) => e.equipoId == equipo.id);
                                final esDeEsteDepto =
                                    equipo.departamentoId ==
                                    revisionProvider
                                        .revisionActual
                                        ?.departamentoId;

                                return ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: esDeEsteDepto
                                          ? const Color(
                                              0xFF135bec,
                                            ).withValues(alpha: 0.1)
                                          : Colors.orange.withValues(
                                              alpha: 0.1,
                                            ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      esDeEsteDepto
                                          ? Icons.computer
                                          : Icons.warning,
                                      color: esDeEsteDepto
                                          ? const Color(0xFF135bec)
                                          : Colors.orange,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          equipo.nombre,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: yaEscaneado
                                                ? Colors.grey
                                                : Colors.black,
                                          ),
                                        ),
                                      ),
                                      if (!esDeEsteDepto)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'OTRO DEPTO',
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Serie: ${equipo.numeroSerie}',
                                        style: TextStyle(
                                          color: yaEscaneado
                                              ? Colors.grey
                                              : null,
                                        ),
                                      ),
                                      Text(
                                        'Depto: ${equipo.departamentoNombre ?? "Sin depto"}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: yaEscaneado
                                              ? Colors.grey
                                              : Colors.grey[600],
                                        ),
                                      ),
                                      if (equipo.trabajadorNombre != null)
                                        Text(
                                          'Asignado a: ${equipo.trabajadorNombre}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: yaEscaneado
                                                ? Colors.grey
                                                : Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: yaEscaneado
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                        )
                                      : const Icon(
                                          Icons.add_circle,
                                          color: Color(0xFF135bec),
                                        ),
                                  enabled: !yaEscaneado,
                                  onTap: yaEscaneado
                                      ? null
                                      : () async {
                                          // Guardar datos necesarios
                                          final equipoSeleccionado = equipo;
                                          final esDeOtroDepto = !esDeEsteDepto;

                                          // Cerrar diálogo
                                          Navigator.pop(dialogContext);

                                          // Pequeña pausa
                                          await Future.delayed(
                                            const Duration(milliseconds: 100),
                                          );

                                          // ✅ USAR EL CONTEXTO DE LA PANTALLA PRINCIPAL
                                          if (!scaffoldContext.mounted) return;

                                          final registrado =
                                              await revisionProvider
                                                  .registrarEquipoEscaneado(
                                                    codigoEscaneado:
                                                        equipoSeleccionado
                                                            .codigoQR,
                                                  );

                                          if (registrado &&
                                              scaffoldContext.mounted) {
                                            String mensaje =
                                                '✅ ${equipoSeleccionado.nombre} registrado';
                                            if (esDeOtroDepto) {
                                              mensaje +=
                                                  ' (equipo de otro depto)';
                                            }

                                            ScaffoldMessenger.of(
                                              scaffoldContext,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(mensaje),
                                                backgroundColor: esDeOtroDepto
                                                    ? Colors.orange
                                                    : Colors.green,
                                                duration: const Duration(
                                                  seconds: 2,
                                                ),
                                              ),
                                            );
                                          } else if (scaffoldContext.mounted) {
                                            ScaffoldMessenger.of(
                                              scaffoldContext,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  revisionProvider.error ??
                                                      'Error al registrar',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('CANCELAR'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ✅ Método auxiliar con verificaciones mounted
  void _registrarPorCodigoManual(String codigo) async {
    if (!mounted) return;

    final revisionProvider = context.read<RevisionProvider>();
    final registrado = await revisionProvider.registrarEquipoEscaneado(
      codigoEscaneado: codigo,
    );

    if (registrado && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Equipo registrado manualmente'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(revisionProvider.error ?? 'Error al registrar'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _finalizarRevision() async {
    if (!mounted) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar Revisión'),
        content: const Text(
          '¿Estás seguro de que quieres finalizar y generar el reporte?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('FINALIZAR'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      final provider = context.read<RevisionProvider>();
      final finalizado = await provider.finalizarRevision();

      if (finalizado && mounted) {
        AppRoutes.goToMissingReport(context);
      }
    }
  }

  void _mostrarOpciones() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Ver Historial'),
                onTap: () {
                  Navigator.pop(context);
                  AppRoutes.goToAuditHistory(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text(
                  'Cancelar Revisión',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _cancelarRevision();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _cancelarRevision() async {
    if (!mounted) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Revisión'),
        content: const Text(
          '¿Estás seguro? Los datos no guardados se perderán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SÍ, CANCELAR'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      final provider = context.read<RevisionProvider>();
      await provider.cancelarRevision();
      if (mounted) {
        AppRoutes.goBack(context);
      }
    }
  }

  // ✅ Verificar en _confirmarSalida
  void _confirmarSalida() async {
    if (!mounted) return;

    if (context.read<RevisionProvider>().equiposRevisados.isEmpty) {
      AppRoutes.goBack(context);
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir de la revisión?'),
        content: const Text('Si sales ahora, perderás el progreso actual.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CONTINUAR'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SALIR'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      AppRoutes.goBack(context);
    }
  }
}
