import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class _Page {
  final String icon;
  final String title;
  final String subtitle;
  final Color primary;
  final Color secondary;
  const _Page({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.secondary,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _controller = PageController();
  int _current = 0;

  late AnimationController _iconCtrl;
  late AnimationController _bgCtrl;
  late Animation<double> _iconScale;
  late Animation<double> _iconFade;
  late Animation<double> _bgAnim;

  final _pages = const [
    _Page(
      icon: '🔧',
      title: 'Recevez des missions',
      subtitle:
          'Acceptez des interventions près de chez vous et développez votre activité de dépannage en Côte d\'Ivoire.',
      primary: Color(0xFFFF6B35),
      secondary: Color(0xFFFF8C5A),
    ),
    _Page(
      icon: '📍',
      title: 'Géolocalisation temps réel',
      subtitle:
          'Soyez visible sur la carte des clients en panne. Activez votre disponibilité en un clic.',
      primary: Color(0xFF2D3748),
      secondary: Color(0xFF4A5568),
    ),
    _Page(
      icon: '💰',
      title: 'Gagnez plus chaque jour',
      subtitle:
          'Suivez vos revenus en temps réel. Payements sécurisés par Orange Money, Wave et carte bancaire.',
      primary: Color(0xFF276749),
      secondary: Color(0xFF38A169),
    ),
    _Page(
      icon: '⭐',
      title: 'Construisez votre réputation',
      subtitle:
          'Collectez des avis clients, montez en note et devenez un prestataire certifié Oyop MT.',
      primary: Color(0xFF744210),
      secondary: Color(0xFFD97706),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _iconCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    _bgCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400),
    );
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut),
    );
    _iconFade = CurvedAnimation(parent: _iconCtrl, curve: Curves.easeOut);
    _bgAnim   = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);
    _iconCtrl.forward();
    _bgCtrl.forward();
  }

  void _onPageChanged(int i) {
    setState(() => _current = i);
    _iconCtrl.reset();
    _bgCtrl.reset();
    _iconCtrl.forward();
    _bgCtrl.forward();
  }

  @override
  void dispose() {
    _iconCtrl.dispose();
    _bgCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_current];
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgAnim,
        builder: (_, child) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                page.primary,
                page.secondary,
                const Color(0xFF1A1A2E),
              ],
            ),
          ),
          child: child,
        ),
        child: SafeArea(
          child: Column(children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo Oyop MT
                  Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('🚐',
                            style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('VigiRoutes Pro',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        )),
                  ]),
                  // Bouton passer
                  TextButton(
                    onPressed: () => context.go('/auth/phone'),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                    ),
                    child: const Text('Passer',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        )),
                  ),
                ],
              ),
            ),

            // ── Pages ───────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (_, i) => _PageContent(
                  page: _pages[i],
                  iconCtrl: _iconCtrl,
                  iconScale: _iconScale,
                  iconFade: _iconFade,
                ),
              ),
            ),

            // ── Dots + Boutons ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
              child: Column(children: [
                // Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) =>
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width:  i == _current ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _current
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                if (_current < _pages.length - 1)
                  // Bouton Suivant
                  SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      onPressed: () => _controller.nextPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: page.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Suivant',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              )),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded,
                              color: page.primary, size: 20),
                        ],
                      ),
                    ),
                  )
                else
                  // Dernière page — bouton unique prestataire
                  SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      onPressed: () => context.go('/auth/phone'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFFF6B35),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🔧',
                              style: TextStyle(fontSize: 20)),
                          SizedBox(width: 10),
                          Text('Commencer à travailler',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              )),
                        ],
                      ),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Page Content ──────────────────────────────────────────────────────────────

class _PageContent extends StatelessWidget {
  final _Page page;
  final AnimationController iconCtrl;
  final Animation<double> iconScale;
  final Animation<double> iconFade;

  const _PageContent({
    required this.page,
    required this.iconCtrl,
    required this.iconScale,
    required this.iconFade,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icône animée dans un cercle
            AnimatedBuilder(
              animation: iconCtrl,
              builder: (_, __) => FadeTransition(
                opacity: iconFade,
                child: ScaleTransition(
                  scale: iconScale,
                  child: Container(
                    width: 130, height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(page.icon,
                          style: const TextStyle(fontSize: 64)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Titre
            AnimatedBuilder(
              animation: iconCtrl,
              builder: (_, __) => FadeTransition(
                opacity: iconFade,
                child: Text(
                  page.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sous-titre
            AnimatedBuilder(
              animation: iconCtrl,
              builder: (_, __) => FadeTransition(
                opacity: iconFade,
                child: Text(
                  page.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.65,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
