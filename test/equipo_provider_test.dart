import 'package:flutter_test/flutter_test.dart';
import 'package:afit_prueba1/database/database_helper.dart';
import 'package:afit_prueba1/models/equipo.dart';
import 'package:afit_prueba1/providers/equipo_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('equipos');
    await db.delete('departamentos');

    await db.insert('departamentos', {
      'id': 'dep-1',
      'nombre': 'TI',
      'cantidad_equipos_asignados': 0,
      'cantidad_personal': 0,
    });

    await db.insert('equipos', Equipo(
      id: 'eq-1',
      codigoQR: 'QR-1',
      nombre: 'Laptop',
      tipo: 'Computadora',
      marca: 'Dell',
      modelo: 'Latitude',
      estado: 'activo',
      numeroSerie: 'SN-1',
      departamentoId: 'dep-1',
      proyectoId: 'proj-1',
      usuarioCreacion: 'tester',
      fechaCreacion: DateTime.now(),
      fechaAdquisicion: DateTime.now(),
    ).toMap());

    await db.insert('equipos', Equipo(
      id: 'eq-2',
      codigoQR: 'QR-2',
      nombre: 'Monitor',
      tipo: 'Monitor',
      marca: 'Samsung',
      modelo: 'SyncMaster',
      estado: 'en espera',
      numeroSerie: 'SN-2',
      departamentoId: 'dep-1',
      proyectoId: 'proj-1',
      usuarioCreacion: 'tester',
      fechaCreacion: DateTime.now(),
      fechaAdquisicion: DateTime.now(),
    ).toMap());
  });

  test('devuelve lista vacía cuando el filtro activo no tiene coincidencias', () async {
    final provider = EquipoProvider();

    await provider.cargarEquipos();
    provider.aplicarFiltros(estado: 'mantenimiento');

    expect(provider.equipos, isEmpty);
  });
}
