import 'package:flutter_test/flutter_test.dart';
import 'package:yerin_mobile/core/models.dart';
import 'package:yerin_mobile/core/router.dart';

void main() {
  const attendee = AppUser(
    id: 1,
    name: 'A',
    email: 'a@example.com',
    role: Role.attendee,
  );
  const admin = AppUser(
    id: 2,
    name: 'B',
    email: 'b@example.com',
    role: Role.admin,
  );
  test('anonymous can discover but cannot checkout', () {
    expect(
      routeRedirect(
        path: '/discover',
        loading: false,
        failed: false,
        user: null,
      ),
      null,
    );
    expect(
      routeRedirect(
        path: '/events/caz/checkout',
        loading: false,
        failed: false,
        user: null,
      ),
      '/login',
    );
  });
  test('roles cannot navigate into management actions', () {
    expect(
      routeRedirect(
        path: '/organizer/new',
        loading: false,
        failed: false,
        user: attendee,
      ),
      '/discover',
    );
    expect(
      routeRedirect(
        path: '/admin/orders',
        loading: false,
        failed: false,
        user: attendee,
      ),
      '/discover',
    );
    expect(
      routeRedirect(
        path: '/organizer/test/edit',
        loading: false,
        failed: false,
        user: admin,
      ),
      '/admin/events',
    );
    expect(
      routeRedirect(
        path: '/orders/3',
        loading: false,
        failed: false,
        user: admin,
      ),
      null,
    );
  });
  test('only expected reset links enter password reset route', () {
    expect(
      passwordResetLocation(
        Uri.parse('yerin://reset-password?token=abc&email=a%2Bb%40example.com'),
      ),
      '/reset-password?token=abc&email=a%2Bb%40example.com',
    );
    expect(
      passwordResetLocation(
        Uri.parse('https://evil.example/reset-password?token=x&email=y'),
      ),
      null,
    );
    expect(passwordResetLocation(Uri.parse('yerin://reset-password')), null);
  });
}
