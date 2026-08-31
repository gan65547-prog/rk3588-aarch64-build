# Cross-compile a Qt 5 Widgets application without CMake.
# Override SYSROOT, TRIPLE, CXX or QT_LIBDIR on the make command line.

TRIPLE ?= aarch64-linux-gnu
SYSROOT ?= $(HOME)/rk3568-qt/sysroot
# A command-line `make CXX=...` override is still honored.  A plain
# environment CXX (often set to the host g++) must not silently defeat the
# cross compiler default.
CXX := $(TRIPLE)-g++
TARGET ?= hello-qt-make

QT_INCLUDEDIR ?= $(SYSROOT)/usr/include/aarch64-linux-gnu/qt5
QT_LIBDIR ?= $(SYSROOT)/usr/lib/aarch64-linux-gnu

CXXFLAGS += --sysroot=$(SYSROOT) -std=c++17 -O2 -fPIC \
	-I$(QT_INCLUDEDIR) \
	-I$(QT_INCLUDEDIR)/QtCore \
	-I$(QT_INCLUDEDIR)/QtGui \
	-I$(QT_INCLUDEDIR)/QtWidgets
LDFLAGS += --sysroot=$(SYSROOT) \
	-L$(QT_LIBDIR) \
	-Wl,-rpath-link,$(SYSROOT)/lib/aarch64-linux-gnu \
	-Wl,-rpath-link,$(SYSROOT)/usr/lib/aarch64-linux-gnu \
	-Wl,-rpath,/usr/lib/aarch64-linux-gnu
LDLIBS += -lQt5Widgets -lQt5Gui -lQt5Core

.PHONY: all clean print-config

all: $(TARGET)

$(TARGET): main.o
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ $^ $(LDLIBS)

main.o: main.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $<

print-config:
	@echo "CXX=$(CXX)"
	@echo "TRIPLE=$(TRIPLE)"
	@echo "SYSROOT=$(SYSROOT)"
	@echo "QT_LIBDIR=$(QT_LIBDIR)"

clean:
	rm -f main.o $(TARGET)
